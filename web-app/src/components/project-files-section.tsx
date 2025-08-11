// /components/project-files-section.tsx
'use client'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { useProjectFiles, CreateFileData, UpdateFileData } from '@/hooks/use-project-files'
import { formatDistanceToNow } from 'date-fns'
import { 
  FileIcon, 
  PlusIcon, 
  MoreHorizontalIcon, 
  EditIcon, 
  TrashIcon,
  UploadIcon,
  FolderIcon 
} from 'lucide-react'
import { Skeleton } from '@/components/ui/skeleton'
import { FileDialog } from '@/components/file-dialog' // Reuse existing dialog
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'
import { Badge } from '@/components/ui/badge'
import type { ProjectFile } from '@/types/app.types'

interface ProjectFilesSectionProps {
  projectId: string;
  isMobile?: boolean;
}

export function ProjectFilesSection({ projectId, isMobile = false }: ProjectFilesSectionProps) {
  const { files, isLoading, isError, createFile, updateFile, deleteFiles } = useProjectFiles(projectId);
  
  // Dialog states
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingFile, setEditingFile] = useState<ProjectFile | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [fileToDelete, setFileToDelete] = useState<number | null>(null);

  const handleCreateFile = () => {
    setEditingFile(null);
    setIsDialogOpen(true);
  };

  const handleEditFile = (file: ProjectFile) => {
    setEditingFile(file);
    setIsDialogOpen(true);
  };

  const handleSaveFile = async (data: CreateFileData | UpdateFileData) => {
    if ('id' in data) {
      await updateFile(data);
    } else {
      await createFile(data);
    }
  };

  const handleDeleteFile = async () => {
    if (fileToDelete) {
      await deleteFiles([fileToDelete]);
      setShowDeleteConfirm(false);
      setFileToDelete(null);
    }
  };

  const renderContent = () => {
    if (isLoading) {
      return (
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="p-3 border border-border/40 rounded-lg">
              <Skeleton className="h-4 w-2/3 mb-2" />
              <Skeleton className="h-3 w-full mb-1" />
              <Skeleton className="h-3 w-1/2" />
            </div>
          ))}
        </div>
      );
    }

    if (isError) {
      return (
        <div className="text-center py-8">
          <FileIcon className="h-8 w-8 text-muted-foreground mx-auto mb-3" />
          <p className="text-sm text-muted-foreground">Failed to load files</p>
        </div>
      );
    }

    if (files.length === 0) {
      return (
        <div className="text-center py-8">
          <FileIcon className="h-8 w-8 text-muted-foreground mx-auto mb-3" />
          <h3 className="font-medium mb-1">No files yet</h3>
          <p className="text-sm text-muted-foreground mb-4">
            Add files to provide context for your AI conversations.
          </p>
          <Button size="sm" onClick={handleCreateFile}>
            <PlusIcon className="w-4 h-4 mr-2" />
            Create File
          </Button>
        </div>
      );
    }

    return (
      <div className="space-y-3">
        {files.map((file) => (
          <div
            key={file.id}
            className="group border border-border/40 rounded-lg p-3 hover:shadow-sm transition-all duration-200"
          >
            <div className="flex items-start justify-between mb-2">
              <div 
                className="flex-1 cursor-pointer"
                onClick={() => handleEditFile(file)}
              >
                <h4 className="font-medium text-sm line-clamp-1 group-hover:text-primary transition-colors">
                  {file.title || 'Untitled'}
                </h4>
                <p className="text-xs text-muted-foreground line-clamp-2 mt-1">
                  {file.content?.substring(0, 80) + (file.content && file.content.length > 80 ? '...' : '') || 'No content'}
                </p>
              </div>
              
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button 
                    variant="ghost" 
                    size="icon" 
                    className="h-7 w-7 opacity-0 group-hover:opacity-100 transition-opacity shrink-0"
                  >
                    <MoreHorizontalIcon className="h-3 w-3" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem onClick={() => handleEditFile(file)}>
                    <EditIcon className="h-4 w-4 mr-2" />
                    Edit
                  </DropdownMenuItem>
                  <DropdownMenuItem 
                    onClick={() => {
                      setFileToDelete(file.id);
                      setShowDeleteConfirm(true);
                    }}
                    className="text-destructive focus:text-destructive"
                  >
                    <TrashIcon className="h-4 w-4 mr-2" />
                    Delete
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
            
            <div className="flex items-center justify-between">
              <p className="text-xs text-muted-foreground">
                {formatDistanceToNow(new Date(file.updated_at), { addSuffix: true })}
              </p>
              <Badge variant="outline" className="text-xs">
                MD
              </Badge>
            </div>
          </div>
        ))}
      </div>
    );
  };

  return (
    <>
      <div className={`flex flex-col p-4`}>
        {/* Header */}
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <FileIcon className="h-5 w-5 text-muted-foreground" />
            <h2 className="font-semibold">Project knowledge</h2>
          </div>
          <Button size="sm" variant="outline" onClick={handleCreateFile}>
            <PlusIcon className="w-4 h-4" />
          </Button>
        </div>

        {/* Capacity indicator */}
        <div className="mb-4">
          <div className="flex items-center justify-between text-sm mb-2">
            <span className="text-muted-foreground">1% of project capacity used</span>
          </div>
          <div className="w-full bg-secondary rounded-full h-1">
            <div className="bg-primary h-1 rounded-full" style={{ width: '1%' }}></div>
          </div>
        </div>

        {/* Files List */}
        <div>
          {renderContent()}
        </div>
      </div>

      {/* File Create/Edit Dialog - Reuse existing FileDialog */}
      <FileDialog
        isOpen={isDialogOpen}
        onOpenChange={setIsDialogOpen}
        onSave={handleSaveFile}
        file={editingFile}
      />

      {/* Delete Confirmation Dialog */}
      <AlertDialog open={showDeleteConfirm} onOpenChange={setShowDeleteConfirm}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Are you sure?</AlertDialogTitle>
            <AlertDialogDescription>
              This will permanently delete this file. This action cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel onClick={() => setFileToDelete(null)}>Cancel</AlertDialogCancel>
            <AlertDialogAction onClick={handleDeleteFile}>Delete</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}