import { NextResponse } from "next/server";

const CLIENT_ID = process.env.AZURE_AD_CLIENT_ID!;
const CLIENT_SECRET = process.env.AZURE_AD_CLIENT_SECRET!;
const TENANT_ID = process.env.AZURE_AD_TENANT_ID!;

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const code = searchParams.get("code");
  const state = searchParams.get("state") ?? "/";

  if (!code) return NextResponse.redirect("/login");

  const tokenRes = await fetch(
    `https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token`,
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        code,
        grant_type: "authorization_code",
        redirect_uri: `${process.env.APP_URL}/auth/callback`,
      }),
    }
  );

  const { access_token } = await tokenRes.json();
  if (!access_token) return NextResponse.redirect("/login?error=1");

  const res = NextResponse.redirect(state);
  res.cookies.set("session", access_token, { httpOnly: true, secure: true });
  return res;
}
