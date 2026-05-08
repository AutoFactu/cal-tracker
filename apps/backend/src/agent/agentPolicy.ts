import { actionDefinitions, type ActionDefinition, type ActionContext } from "@cal-tracker/contracts";

export function filterToolsByPolicy(actions: ActionDefinition[], context: ActionContext): ActionDefinition[] {
  return actions.filter((action) => {
    // 1. Scope check
    if (!context.scopes.includes(action.permissionScope)) return false;
    return true;
  });
}
