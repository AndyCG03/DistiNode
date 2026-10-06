import "server-only";
import nodemailer, { type Transporter } from "nodemailer";

let transport: Transporter | null = null;

/** SMTP_URL, p. ej. smtp://usuario:clave@smtp.ejemplo.com:587. En Docker por defecto: Mailpit. */
function mailer() {
  const url = process.env.SMTP_URL;
  if (!url) throw new Error("Falta SMTP_URL para enviar el enlace mágico.");
  transport ??= nodemailer.createTransport(url);
  return transport;
}

export async function sendMagicLinkEmail(to: string, url: string) {
  const from = process.env.MAIL_FROM || "DistiNode <no-responder@distinode.local>";
  await mailer().sendMail({
    from,
    to,
    subject: "Tu enlace para entrar a DistiNode",
    text: `Hola:\n\nPulsa este enlace para entrar a DistiNode (caduca en 15 minutos):\n${url}\n\nSi no lo pediste, ignora este correo.`,
    html: `<div style="font-family:system-ui,sans-serif;max-width:480px;margin:auto;padding:24px;color:#14211c">
  <p style="font-size:20px;font-weight:700;margin:0 0 16px"><span style="color:#00704f">Disti</span>Node</p>
  <p>Pulsa el botón para entrar. El enlace caduca en 15 minutos.</p>
  <p style="margin:24px 0"><a href="${url}" style="background:#00704f;color:#fff;padding:12px 20px;border-radius:999px;text-decoration:none;font-weight:600">Entrar a DistiNode</a></p>
  <p style="color:#5d6561;font-size:13px">Si no lo pediste, ignora este correo.</p>
</div>`,
  });
}
