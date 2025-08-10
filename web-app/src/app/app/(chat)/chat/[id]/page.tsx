// src/app/app/(chat)/chat/[id]/page.tsx
import { createClient } from '@/utils/supabase/server';
import { redirect } from 'next/navigation';
import { Chat } from '@/components/chat';
import { getChatById, getMessagesByChatId, getUser } from '@/utils/supabase/queries';
import { notFound } from 'next/navigation';
import { Attachment, UIMessage } from 'ai';
import { Database } from '@/types/database.types';
import { ModeType } from '@/types/app.types';
import { getProjectById } from '@/utils/supabase/queries';
import { generateUUID } from '@/lib/utils';

type DBMessage = Database['public']['Tables']['messages']['Row'];

export default async function Page(props: { 
  params: Promise<{ id: string }>;
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
}) {
  const supabase = await createClient();
  const user = await getUser(supabase);

  if (!user) {
    return redirect("/sign-in");
  }
  
  const params = await props.params;
  const searchParams = await props.searchParams;
  const { id } = params;

  // Check if this is a new chat from project page
  const initialMessage = searchParams.initialMessage;
  let projectId = typeof searchParams.projectId === 'string' ? searchParams.projectId : undefined;
  const mode = typeof searchParams.mode === 'string' ? searchParams.mode as ModeType : 'coach';

  let initialMessages: Array<UIMessage> = [];
  let chatData = null;
  let newMessage: UIMessage | null = null;

  if (initialMessage && typeof initialMessage === 'string') {
    // NEW CHAT: Create the user message
    const messageId = generateUUID();
    const userMessage: UIMessage = {
      id: messageId,
      role: 'user',
      content: decodeURIComponent(initialMessage),
      parts: [{ type: 'text', text: decodeURIComponent(initialMessage) }],
      createdAt: new Date(),
      experimental_attachments: [],
    };

    newMessage = userMessage;

    // Get project info for header
    if (projectId) {
      const project = await getProjectById(supabase, projectId);
      chatData = {
        id,
        title: 'Untitled',
        project_id: projectId,
        projects: project
      };
    }
  } else {
    // EXISTING CHAT: Load from database
    const chat = await getChatById(supabase, id);
    if (!chat) {
      notFound();
    }

    if (chat.visibility === 'private' && user.id !== chat.user_id) {
      return notFound();
    }

    const messagesFromDb = await getMessagesByChatId(supabase, id);
    initialMessages = convertToUIMessages(messagesFromDb);
    chatData = chat;
  }

  function convertToUIMessages(messages: Array<DBMessage>): Array<UIMessage> {
    return messages.map((message) => ({
      id: message.id,
      parts: message.parts as UIMessage['parts'],
      role: message.role as UIMessage['role'],
      content: (message.parts as UIMessage['parts'])?.filter(part => part.type === 'text').map(part => (part as { text: string, type: 'text' }).text).join('') || '',
      createdAt: new Date(message.created_at),
      experimental_attachments: [],
    }));
  }

  // Extract project information from the chat
  const projectName = chatData?.projects?.name;
  projectId = chatData?.project_id
  const chatTitle = chatData?.title;

  console.log('from chat page project name, chat title:', {projectName, chatTitle})

  // Check if we need to resume streaming
  // const resumeStream = searchParams.resumeStream === 'true';
  // const messageId = typeof searchParams.messageId === 'string' ? searchParams.messageId : undefined;
  

  // console.log(`Rendering chat ${id} with resumeStream=${resumeStream}, messageId=${messageId}, mode=${mode}`);
  console.log(`Rendering chat ${id} with mode=${mode}, initialMessage=${initialMessage}, projectId=${projectId}`);

  return (
    <>
      <Chat
        id={id}
        initialMessages={initialMessages}
        selectedVisibilityType="private"
        isReadonly={false}
        projectId={projectId}
        projectName={projectName}
        chatTitle={chatTitle}
        // resumeStream={resumeStream}
        // streamingMessageId={messageId}
        initialMode={mode}
        isNewChat={!!initialMessage} // Indicate if this is a new chat
        newMessage={newMessage}
      />
    </>
  );
}