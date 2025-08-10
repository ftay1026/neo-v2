export type VisibilityType = 'private' | 'public';

export type ModeType = 'assistant' | 'coach';

export interface Project {
  id: string;
  name: string;
  description?: string;
  is_default: boolean;
  created_at: string;
  updated_at: string;
}

export interface ProjectFile {
  id: number;
  title: string | null;
  content: string | null;
  created_at: string;
  updated_at: string;
}