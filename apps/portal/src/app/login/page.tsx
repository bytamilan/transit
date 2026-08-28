import { Suspense } from "react";
import LoginForm from "./login-form";

export default function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center p-4 bg-radial from-primary/5 via-background to-background">
      <Suspense>
        <LoginForm />
      </Suspense>
    </main>
  );
}
