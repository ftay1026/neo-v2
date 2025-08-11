'use client';

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import type { Project } from '@/types/app.types';
import type { CreateProjectData, UpdateProjectData } from '@/hooks/use-projects';

interface ProjectDialogProps {
  isOpen: boolean;
  onOpenChange: (open: boolean) => void;
  onSave: (data: CreateProjectData | UpdateProjectData) => Promise<void>;
  project?: Project | null; // null for create, Project for edit
  isLoading?: boolean;
  hasOtherDefaultProject?: boolean; // To control default checkbox visibility
}

export function ProjectDialog({ 
  isOpen, 
  onOpenChange, 
  onSave, 
  project, 
  isLoading = false,
  hasOtherDefaultProject = false
}: ProjectDialogProps) {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [isDefault, setIsDefault] = useState(false);
  const [isSaving, setIsSaving] = useState(false);

  const isEditMode = !!project;

  // Reset form when dialog opens/closes or project changes
  useEffect(() => {
    if (isOpen) {
      setName(project?.name || '');
      setDescription(project?.description || '');
      setIsDefault(project?.is_default || false);
    } else {
      setName('');
      setDescription('');
      setIsDefault(false);
    }
  }, [isOpen, project]);

  const handleSave = async () => {
    if (!name.trim()) {
      return; // Name is required
    }

    setIsSaving(true);
    try {
      if (isEditMode && project) {
        await onSave({
          id: project.id,
          name: name.trim(),
          description: description.trim() || undefined,
          is_default: isDefault,
        });
      } else {
        await onSave({
          name: name.trim(),
          description: description.trim() || undefined,
          is_default: isDefault,
        });
      }
      onOpenChange(false);
    } catch (error) {
      // Error handling is done in the hook
    } finally {
      setIsSaving(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
      e.preventDefault();
      handleSave();
    }
  };

  // Don't show default checkbox if editing default project or if there's already another default
  const showDefaultCheckbox = !isEditMode || (!project?.is_default && !hasOtherDefaultProject);

  return (
    <Dialog open={isOpen} onOpenChange={onOpenChange}>
      <DialogContent 
        className="w-[95vw] sm:max-w-[500px] max-h-[90vh] flex flex-col" 
        onKeyDown={handleKeyDown}
      >
        <DialogHeader className="flex-shrink-0">
          <DialogTitle>
            {isEditMode ? 'Edit Project' : 'Create New Project'}
          </DialogTitle>
          <DialogDescription>
            {isEditMode 
              ? 'Make changes to your project. Click save when you\'re done.'
              : 'Create a new project to organize your chats and files.'
            }
          </DialogDescription>
        </DialogHeader>
        
        <div className="flex-1 overflow-hidden flex flex-col">
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="name">Project Name</Label>
              <Input
                id="name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Enter project name..."
                disabled={isSaving}
                autoFocus
              />
            </div>
            
            <div className="grid gap-2">
              <Label htmlFor="description">Description (Optional)</Label>
              <Textarea
                id="description"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Enter project description..."
                className="min-h-[100px] resize-y"
                disabled={isSaving}
              />
            </div>

            {showDefaultCheckbox && (
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="default"
                  checked={isDefault}
                  onCheckedChange={(checked) => setIsDefault(checked as boolean)}
                  disabled={isSaving}
                />
                <Label htmlFor="default" className="text-sm">
                  Set as default project
                </Label>
              </div>
            )}

            {isEditMode && project?.is_default && (
              <div className="text-xs text-muted-foreground bg-muted p-2 rounded">
                💡 This is your default project and cannot be changed to non-default.
              </div>
            )}
          </div>
        </div>
        
        <DialogFooter className="flex-shrink-0 mt-4">
          <Button 
            variant="outline" 
            onClick={() => onOpenChange(false)}
            disabled={isSaving}
          >
            Cancel
          </Button>
          <Button 
            onClick={handleSave} 
            disabled={!name.trim() || isSaving}
          >
            {isSaving ? 'Saving...' : (isEditMode ? 'Save Changes' : 'Create Project')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}