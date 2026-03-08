import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

const ALLOWED_DOMAINS = (process.env.NEXT_PUBLIC_ALLOWED_ADMIN_DOMAINS || "")
  .split(",")
  .map((d) => d.trim().toLowerCase())
  .filter(Boolean);

export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const isLoginPage = request.nextUrl.pathname === "/login";

  if (isLoginPage) {
    if (user && ALLOWED_DOMAINS.length > 0) {
      const email = (user.email || "").toLowerCase();
      const allowed = ALLOWED_DOMAINS.some(
        (domain) => email.endsWith(`@${domain}`) || email === domain
      );
      if (allowed) {
        response = NextResponse.redirect(new URL("/", request.url));
      }
    }
    return response;
  }

  if (!user) {
    response = NextResponse.redirect(new URL("/login", request.url));
    return response;
  }

  if (ALLOWED_DOMAINS.length > 0) {
    const email = (user.email || "").toLowerCase();
    const allowed = ALLOWED_DOMAINS.some(
      (domain) => email.endsWith(`@${domain}`) || email === domain
    );
    if (!allowed) {
      await supabase.auth.signOut();
      response = NextResponse.redirect(
        new URL("/login?error=domain", request.url)
      );
      return response;
    }
  }

  return response;
}
