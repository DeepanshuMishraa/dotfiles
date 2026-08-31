/** Short alias for Plannotator's plan-mode command. */
const PLANNOTATOR_REQUEST_CHANNEL = "plannotator:request";

export default function pplanExtension(pi: any): void {
  pi.registerCommand("pplan", {
    description: "Toggle Plannotator plan mode",
    handler: async (_args: string, ctx: any) => {
      pi.events.emit(PLANNOTATOR_REQUEST_CHANNEL, {
        requestId: crypto.randomUUID(),
        action: "plan-mode",
        payload: { mode: "toggle" },
        respond: (response: any) => {
          if (response?.status === "unavailable") {
            ctx.ui.notify(response.error ?? "Plannotator is not ready.", "error");
          } else if (response?.status === "error") {
            ctx.ui.notify(response.error ?? "Unable to toggle Plannotator plan mode.", "error");
          }
        },
      });
    },
  });
}
