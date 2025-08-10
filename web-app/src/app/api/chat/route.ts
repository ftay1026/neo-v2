import {
  UIMessage,
  createDataStreamResponse,
  streamText,
  appendResponseMessages,
  smoothStream,
  generateText,
  Message
} from 'ai';
import { systemPrompt } from '@/lib/ai/prompts';
import {
  getChatById,
  saveChat,
  saveMessages,
  deleteChatById,
  getUser,
  getUserDefaultProject,
  updateChatTitle,
} from '@/utils/supabase/queries';
import {
  generateUUID,
  getMostRecentUserMessage,
  getTrailingMessageId,
} from '@/lib/utils';
import { anthropic } from '@ai-sdk/anthropic';
import { openai } from '@ai-sdk/openai';
import { createClient } from '@/utils/supabase/server';
import { getHitPayCustomerId } from '@/utils/hitpay/get-customer-ids';
import { createClient as createAdminClient } from '@/utils/supabase/admin';
import { Database } from '@/types/database.types';
import { SupabaseClient } from '@supabase/supabase-js';
import { ModeType } from '@/types/app.types';

export const maxDuration = 60;

async function generateTitleFromUserMessage({
  message,
}: {
  message: Message;
}) {
  const { text: title } = await generateText({
    model: openai('gpt-4.1'),
    temperature: 0.5,
    maxTokens: 50,
    system: `\n
    - you will generate a short title based on the first message a user begins a conversation with
    - ensure it is not more than 80 characters long
    - the title should be a summary of the user's message
    - do not use quotes or colons`,
    prompt: JSON.stringify(message),
  });

  return title;
}

async function generateEmbedding(text: string): Promise<number[]> {
  try {
  const response = await fetch('https://api.openai.com/v1/embeddings', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: 'text-embedding-ada-002',
      input: text
    })
  });
  
  const result = await response.json();

  // Check if the response has the expected structure
  if (!result.data || !Array.isArray(result.data) || result.data.length === 0) {
    throw new Error('Invalid response structure from OpenAI API');
  }
  
  if (!result.data[0].embedding || !Array.isArray(result.data[0].embedding)) {
    throw new Error('Invalid embedding data from OpenAI API');
  }

  const vector: number[] = result.data[0].embedding;
  
  // Normalize vector for better similarity search performance
  const magnitude = Math.sqrt(vector.reduce((sum: number, val: number) => sum + val * val, 0));
  return vector.map((val: number) => val / magnitude);
 } catch (error) {
    console.error('Error generating embedding:', error);
    // Return a zero vector as fallback (this will not match any documents)
    return new Array(1536).fill(0);
  }
}

export async function POST(request: Request) {
  try {
    const {
      id,
      messages,
      mode,
      projectId
    }: {
      id: string;
      messages: Array<UIMessage>;
      mode?: ModeType | null;
      projectId?: string | null;
    } = await request.json();

    const supabase: SupabaseClient<Database> = await createClient();
    
    const user = await getUser(supabase);
    
    if (!user?.id) {
      return new Response('Unauthorized', { status: 401 });
    }

    // Get customer ID and check credits
    const customerId = await getHitPayCustomerId();
    if (!customerId) {
      return new Response('Customer record not found. Please make a purchase to proceed.', { status: 404 });
    }

    const supabaseAdmin: SupabaseClient<Database> = await createAdminClient();

    // Check if user has enough credits using the customer_id
    const { data: hasEnoughCredits, error: creditError } = await supabaseAdmin.rpc('check_and_deduct_credits', {
      p_customer_id: customerId,
      p_required_credits: 1
    });

    if (creditError) {
      console.error('Credit check error:', creditError);
      return new Response('An error occurred while checking credits', { 
        status: 500,
        statusText: 'Credit check failed'
      });
    }

    if (!hasEnoughCredits) {
      return new Response('Insufficient credits. Please purchase more credits to continue.', { 
        status: 402,
        statusText: 'Insufficient credits'
      });
    }

    const userMessage = getMostRecentUserMessage(messages);

    if (!userMessage) {
      return new Response('No user message found', { 
        status: 400,
        statusText: 'Invalid request'
      });
    }

    // Get user's default project if no specific project ID is provided
    let targetProjectId = projectId;

    if (!targetProjectId) {
      const defaultProject = await getUserDefaultProject(supabase);
      targetProjectId = defaultProject?.id;
    }

    if (!targetProjectId || targetProjectId === 'null' || targetProjectId === 'undefined') {
      return new Response('No project available for chat', { status: 400 });
    }

    // Check if chat exists and handle chat creation
    const existingChat = await getChatById(supabase, id);
    const isNewChat = !existingChat;
    
    if (isNewChat) {
      // Create chat with placeholder title - will be updated after first response
      await saveChat(supabase, id, 'Untitled', targetProjectId);
    } else {
      if (existingChat.user_id !== user.id) {
        return new Response('Unauthorized', { status: 401 });
      }
    }

    // Save user message
    await saveMessages(supabase, [
      {
        chat_id: id,
        id: userMessage.id,
        role: 'user',
        parts: userMessage.parts,
        attachments: userMessage.experimental_attachments ?? [],
        created_at: new Date().toISOString(),
      },
    ]);

    // Generate embedding and search for relevant documents
    const queryEmbedding = await generateEmbedding(userMessage.content);
    
    // Search for relevant document chunks
    const { data: relevantDocs, error: searchError } = await supabase.rpc(
      'match_document_sections_by_project',
      {
        query_embedding: JSON.stringify(queryEmbedding), // Reference: https://github.com/supabase-community/chatgpt-your-files/blob/2bb8afb723c85a672e845be148842e442d0f9d3b/supabase/functions/embed/index.ts#L76
        match_threshold: 0.7,
        match_count: 5,
        p_user_id: user.id,
        p_project_id: targetProjectId
      }
    );
    
    if (searchError) {
      console.error('Document search error:', searchError);
    }
    
    // Construct context from relevant documents
    let documentContext = '';
    if (relevantDocs && relevantDocs.length > 0) {
      documentContext = '\nContext from user Files:\n\n';
      relevantDocs.forEach((doc, index) => {
        documentContext += `[${doc.filename}]\n${doc.content}\n\n`;
      });
      
      documentContext = `---\nUse the below context to provide relevant insights to the user, but don't explicitly mention that you're reading from these files unless the user asks about their Files.\n---\n\n` + documentContext + `---\nEnd of context from user Files.\n---\n\n`;
    }

    // Update the system prompt with document context
    const enhancedSystemPrompt = documentContext 
      ? `${systemPrompt(mode ?? null)}\n\n${documentContext}`
      : systemPrompt(mode ?? null);

    return createDataStreamResponse({
      execute: (dataStream) => {
        const result = streamText({
          model: anthropic('claude-3-5-sonnet-20241022'),
          system: enhancedSystemPrompt,
          messages,
          maxSteps: 5,
          experimental_activeTools: [],
          experimental_transform: smoothStream({ chunking: 'word' }),
          experimental_generateMessageId: generateUUID,
          onFinish: async ({ response }) => {
            if (!user.id) return;

            try {
              const assistantId = getTrailingMessageId({
                messages: response.messages.filter(
                  (message) => message.role === 'assistant',
                ),
              });

              if (!assistantId) {
                throw new Error('No assistant message found!');
              }

              const [, assistantMessage] = appendResponseMessages({
                messages: [userMessage],
                responseMessages: response.messages,
              });

              // Save assistant message
              await saveMessages(supabase, [
                {
                  id: assistantId,
                  chat_id: id,
                  role: assistantMessage.role as 'assistant',
                  parts: assistantMessage.parts ?? [],
                  attachments:
                    assistantMessage.experimental_attachments ?? [],
                  created_at: new Date().toISOString(),
                },
              ]);

              // Generate and update title for new chats
              if (isNewChat) {
                try {
                  const newTitle = await generateTitleFromUserMessage({
                    message: userMessage,
                  });
                  
                  await updateChatTitle(supabase, id, newTitle);
                  
                  // Send title update through data stream
                  dataStream.writeData({
                    type: 'title-update',
                    title: newTitle,
                  });
                } catch (titleError) {
                  console.error('Failed to generate/update title:', titleError);
                  // Don't fail the entire request if title update fails
                }
              }

            } catch (error) {
              console.error('Failed to save chat messages:', error);
              // Don't throw here to avoid breaking the stream
            }
          },
        });

        result.mergeIntoDataStream(dataStream, {
          sendReasoning: true,
        });
      },
      onError: (error) => {
        console.error('Error in streamText', error);
        return 'Oops, an error occurred!';
      },
    });
  } catch (error) {
    console.error('Error in POST request', error);
    return new Response('An error occurred while processing your request.', {
      status: 500,
      statusText: 'Internal server error'
    });
  }
}

export async function DELETE(request: Request) {
  const { searchParams } = new URL(request.url);
  const id = searchParams.get('id');

  if (!id) {
    return new Response('Not Found', { status: 404 });
  }

  const supabase = await createClient();

  const user = await getUser(supabase);

  if (!user || !user.id) {
    return new Response('Unauthorized', { status: 401 });
  }

  try {
    const chat = await getChatById(supabase, id);

    if (!chat) {
      return new Response('Chat not found', { status: 404 });
    }

    if (chat.user_id !== user.id) {
      return new Response('Unauthorized', { status: 401 });
    }

    await deleteChatById(supabase, id);

    return new Response('Chat deleted', { status: 200 });
  } catch (error) {
    return new Response('An error occurred while processing your request!', {
      status: 500,
    });
  }
}
