'use client';

import type { Attachment, UIMessage } from 'ai';
import { cn } from '@/lib/utils'
import type React from 'react';
import {
  useRef,
  useEffect,
  useState,
  useCallback,
  type Dispatch,
  type SetStateAction,
  type ChangeEvent,
  memo,
} from 'react';
import { toast } from 'sonner';
import { useLocalStorage, useWindowSize } from 'usehooks-ts';

import { ArrowUpIcon, StopIcon } from './icons';
import { Button } from './ui/button';
import { Textarea } from './ui/textarea';
import { UseChatHelpers } from '@ai-sdk/react';
import { Toggle } from "@/components/ui/toggle"
import { ModeType } from '@/types/app.types';
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";

function PureMultimodalInput({
  chatId,
  input,
  mode,
  handleModeChange,
  setInput,
  status,
  stop,
  messages,
  setMessages,
  handleSubmit,
  className,
  placeholder = "Send a message...", // New prop with default value
  customSubmit, // New prop for custom submit handler
}: {
  chatId: string;
  input: UseChatHelpers['input'];
  setInput: UseChatHelpers['setInput'];
  mode: ModeType;
  handleModeChange: (mode: ModeType) => void;
  status: UseChatHelpers['status'];
  stop: () => void;
  messages: Array<UIMessage>;
  setMessages: UseChatHelpers['setMessages'];
  handleSubmit: UseChatHelpers['handleSubmit'];
  className?: string;
  placeholder?: string;
  customSubmit?: (e: React.FormEvent) => Promise<void>;
}) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const { width } = useWindowSize();

  useEffect(() => {
    if (textareaRef.current) {
      adjustHeight();
    }
  }, []);

  const adjustHeight = () => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = `${textareaRef.current.scrollHeight + 2}px`;
    }
  };

  const resetHeight = () => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = '120px'; // Increased from 98px
    }
  };

  const [localStorageInput, setLocalStorageInput] = useLocalStorage(
    'input',
    '',
  );

  useEffect(() => {
    if (textareaRef.current) {
      const domValue = textareaRef.current.value;
      // Prefer DOM value over localStorage to handle hydration
      const finalValue = domValue || localStorageInput || '';
      setInput(finalValue);
      adjustHeight();
    }
    // Only run once after hydration
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    setLocalStorageInput(input);
  }, [input, setLocalStorageInput]);

  const handleInput = (event: React.ChangeEvent<HTMLTextAreaElement>) => {
    setInput(event.target.value);
    adjustHeight();
  };

  const submitForm = useCallback((e?: React.FormEvent) => {
    if (e) e.preventDefault();

    // Use custom submit handler if provided
    if (customSubmit) {
      customSubmit(e || new Event('submit') as any);
      setLocalStorageInput('');
      resetHeight();
      return;
    }

    window.history.replaceState({}, '', `/app/chat/${chatId}`);

    handleSubmit(undefined);

    setLocalStorageInput('');
    resetHeight();

    if (width && width > 768) {
      textareaRef.current?.focus();
    }
  }, [
    handleSubmit,
    setLocalStorageInput,
    width,
    chatId,
    customSubmit,
  ]);

  return (
    <div className="relative w-full flex flex-col gap-4">
      <Textarea
        data-testid="multimodal-input"
        ref={textareaRef}
        placeholder={placeholder}
        value={input}
        onChange={handleInput}
        className={cn(
          'min-h-[120px] max-h-[calc(75dvh)] overflow-hidden resize-none rounded-2xl !text-base pb-16 pr-14 pl-4 pt-4 dark:border-zinc-700',
          className,
        )}
        rows={3} // Increased from 2
        autoFocus
        onKeyDown={(event) => {
          if (
            event.key === 'Enter' &&
            !event.shiftKey &&
            !event.nativeEvent.isComposing
          ) {
            event.preventDefault();

            if (status !== 'ready') {
              toast.error('Please wait for the model to finish its response!');
            } else {
              submitForm();
            }
          }
        }}
      />

      <div className="absolute bottom-3 w-full">
        <div className="flex flex-row gap-2 items-center justify-between px-3">
          <div className="w-fit">
            <ModeButton
              mode={mode}
              handleModeChange={handleModeChange}
            />
          </div>

          <div className="w-fit">
            {status === 'submitted' ? (
              <StopButton stop={stop} setMessages={setMessages} />
            ) : (
              <SendButton
                input={input}
                submitForm={submitForm}
              />
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export const ChatInput = memo(
  PureMultimodalInput,
  (prevProps, nextProps) => {
    if (prevProps.input !== nextProps.input) return false;
    if (prevProps.status !== nextProps.status) return false;
    if (prevProps.mode !== nextProps.mode) return false;

    return true;
  },
);

function PureStopButton({
  stop,
  setMessages,
}: {
  stop: () => void;
  setMessages: UseChatHelpers['setMessages'];
}) {
  return (
    <Button
      data-testid="stop-button"
      className="rounded-full p-1.5 h-fit border dark:border-zinc-600"
      onClick={(event) => {
        event.preventDefault();
        stop();
        setMessages((messages) => messages);
      }}
    >
      <StopIcon size={14} />
    </Button>
  );
}

const StopButton = memo(PureStopButton);

function PureSendButton({
  submitForm,
  input,
}: {
  submitForm: () => void;
  input: string;
}) {
  return (
    <Button
      data-testid="send-button"
      className="rounded-full p-1.5 h-fit border dark:border-zinc-600 bg-secondary text-secondary-foreground hover:bg-secondary/90"
      onClick={(event) => {
        event.preventDefault();
        submitForm();
      }}
      disabled={input.length === 0}
    >
      <ArrowUpIcon size={14} />
    </Button>
  );
}

const SendButton = memo(PureSendButton, (prevProps, nextProps) => {
  if (prevProps.input !== nextProps.input) return false;
  return true;
});

// Mode button to switch between coach, and assistant modes in system prompt
const PureModeButton = ({mode, handleModeChange}: {mode: ModeType; handleModeChange: (mode: ModeType) => void}) => {
  const handleToggleChange = () => {
    const newMode = mode === 'assistant' ? 'coach' : 'assistant';
    handleModeChange(newMode);
  };
  const modes = [
    { value: 'assistant', label: 'Assistant' },
    { value: 'coach', label: 'Coach' },
  ];
  
  return (
    <div className='flex items-center gap-2'>
      <Tooltip>
        <TooltipTrigger asChild>
          <div>
            <Toggle
              className='h-8 w-fit cursor-pointer'
              aria-label='Toggle Coaching Mode'
              pressed={mode === 'coach'}
              onPressedChange={handleToggleChange}
            >
              <span className='text-xs'>
                { mode === 'coach' ? 'C' : 'C' }
              </span>
            </Toggle>
          </div>
        </TooltipTrigger>
        <TooltipContent>
          <p>Coaching Mode</p>
        </TooltipContent>
      </Tooltip>
    </div>
  );
}
const ModeButton = memo(PureModeButton, (prevProps, nextProps) => {
  if (prevProps.mode !== nextProps.mode) return false;
  return true;
});
