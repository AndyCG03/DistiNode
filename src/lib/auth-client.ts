"use client";

import { magicLinkClient } from "better-auth/client/plugins";
import { createAuthClient } from "better-auth/react";

// Mismo origen que la página: no hace falta configurar la URL en el cliente.
export const authClient = createAuthClient({ plugins: [magicLinkClient()] });
