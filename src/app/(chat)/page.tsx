import { createClient } from "@/utils/supabase/server";
import { getUser, getUserDefaultProject } from "@/utils/supabase/queries";
import { redirect } from "next/navigation";

export default async function Page() {
  const supabase = await createClient();
  const [user, defaultProject] = await Promise.all([
    getUser(supabase),
    getUserDefaultProject(supabase),
  ]);

  if (!user) {
    redirect("/sign-in");
  }

  if (defaultProject?.id) {
    redirect(`/app/project/${defaultProject.id}`);
  }

  redirect("/app/projects");

  // Render something invisible so manifest is created
  return <div style={{ display: "none" }}>Redirecting...</div>;
}
