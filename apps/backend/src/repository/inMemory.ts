import { defaultUserScopes, type Meal, type MealItem, type MealProposal, type MealTemplate, type NutritionSnapshot } from "@cal-tracker/contracts";
import { newId } from "../utils/ids.js";
import { normalizeText } from "../utils/normalize.js";
import { subtractNutrition, sumNutrition } from "../utils/nutrition.js";
import type {
  ActionCallRecord,
  AppRepository,
  AuditEventRecord,
  FoodItemRecord,
  MemoryMatch,
  StoredSession,
  StoredUser
} from "./types.js";

export class InMemoryRepository implements AppRepository {
  private users = new Map<string, StoredUser>();
  private sessions = new Map<string, StoredSession>();
  private passwordResetTokens = new Map<string, { userId: string; expiresAt: string; usedAt?: string }>();
  private foods = new Map<string, FoodItemRecord>();
  private targets = new Map<string, NutritionSnapshot>();
  private proposals = new Map<string, MealProposal & { userId: string }>();
  private meals = new Map<string, Meal & { userId: string }>();
  private templates = new Map<string, MealTemplate & { userId: string }>();
  private memories = new Map<string, { id: string; userId: string; normalizedText: string; label: string; templateId?: string; confidence: number; usageCount: number }>();
  private actionCalls: ActionCallRecord[] = [];
  private auditEvents: AuditEventRecord[] = [];

  static seeded(): InMemoryRepository {
    const repo = new InMemoryRepository();
    repo.seedFoods();
    return repo;
  }

  seedFoods(): void {
    const foods: FoodItemRecord[] = [
      { id: newId(), name: "Egg", normalizedName: "egg", source: "generic_usda", servingGrams: 50, calories: 72, proteinGrams: 6.3, carbsGrams: 0.4, fatGrams: 4.8 },
      { id: newId(), name: "Chicken breast", normalizedName: "chicken breast", source: "generic_usda", servingGrams: 100, calories: 165, proteinGrams: 31, carbsGrams: 0, fatGrams: 3.6 },
      { id: newId(), name: "Cooked rice", normalizedName: "rice", source: "generic_usda", servingGrams: 100, calories: 130, proteinGrams: 2.7, carbsGrams: 28, fatGrams: 0.3 },
      { id: newId(), name: "Oats", normalizedName: "oats", source: "generic_usda", servingGrams: 100, calories: 389, proteinGrams: 16.9, carbsGrams: 66.3, fatGrams: 6.9 },
      { id: newId(), name: "Milk", normalizedName: "milk", source: "generic_usda", servingGrams: 250, calories: 122, proteinGrams: 8.1, carbsGrams: 12, fatGrams: 4.8 },
      { id: newId(), name: "Bread", normalizedName: "bread", source: "generic_usda", servingGrams: 100, calories: 265, proteinGrams: 9, carbsGrams: 49, fatGrams: 3.2 },
      { id: newId(), name: "Butter", normalizedName: "butter", source: "generic_usda", servingGrams: 100, calories: 717, proteinGrams: 0.9, carbsGrams: 0.1, fatGrams: 81.1 },
      { id: newId(), name: "Ham", normalizedName: "ham", source: "generic_usda", servingGrams: 100, calories: 145, proteinGrams: 21, carbsGrams: 1.5, fatGrams: 5.5 }
    ];
    for (const food of foods) this.foods.set(food.id, food);
  }

  async createUser(input: { email: string; displayName: string; passwordHash: string; scopes?: typeof defaultUserScopes }): Promise<StoredUser> {
    if (await this.findUserByEmail(input.email)) {
      throw new Error("email_already_registered");
    }
    const user: StoredUser = {
      id: newId(),
      email: input.email.toLowerCase(),
      displayName: input.displayName,
      trustedModeEnabled: false,
      createdAt: new Date().toISOString(),
      passwordHash: input.passwordHash,
      scopes: input.scopes ?? defaultUserScopes
    };
    this.users.set(user.id, user);
    this.targets.set(user.id, { calories: 2200, proteinGrams: 160, carbsGrams: 240, fatGrams: 70 });
    await this.createDefaultTemplate(user.id);
    return user;
  }

  async findUserByEmail(email: string): Promise<StoredUser | undefined> {
    return [...this.users.values()].find((user) => user.email === email.toLowerCase());
  }

  async findUserById(id: string): Promise<StoredUser | undefined> {
    return this.users.get(id);
  }

  async updateTrustedMode(userId: string, enabled: boolean): Promise<StoredUser> {
    const user = this.requireUser(userId);
    user.trustedModeEnabled = enabled;
    return user;
  }

  async createSession(input: Omit<StoredSession, "createdAt">): Promise<StoredSession> {
    const session = { ...input, createdAt: new Date().toISOString() };
    this.sessions.set(session.id, session);
    return session;
  }

  async findSessionByRefreshTokenHash(hash: string): Promise<StoredSession | undefined> {
    const now = Date.now();
    return [...this.sessions.values()].find(
      (session) => session.refreshTokenHash === hash && !session.revokedAt && Date.parse(session.expiresAt) > now
    );
  }

  async revokeSession(sessionId: string): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (session) session.revokedAt = new Date().toISOString();
  }

  async revokeAllSessions(userId: string): Promise<void> {
    for (const session of this.sessions.values()) {
      if (session.userId === userId) session.revokedAt = new Date().toISOString();
    }
  }

  async rotateSession(sessionId: string, nextHash: string, expiresAt: string): Promise<StoredSession> {
    const session = this.sessions.get(sessionId);
    if (!session) throw new Error("session_not_found");
    session.refreshTokenHash = nextHash;
    session.expiresAt = expiresAt;
    session.rotatedAt = new Date().toISOString();
    return session;
  }

  async createPasswordReset(input: { userId: string; tokenHash: string; expiresAt: string }): Promise<void> {
    this.passwordResetTokens.set(input.tokenHash, { userId: input.userId, expiresAt: input.expiresAt });
  }

  async consumePasswordReset(tokenHash: string, newPasswordHash: string): Promise<boolean> {
    const reset = this.passwordResetTokens.get(tokenHash);
    if (!reset || reset.usedAt || Date.parse(reset.expiresAt) < Date.now()) return false;
    const user = this.requireUser(reset.userId);
    user.passwordHash = newPasswordHash;
    reset.usedAt = new Date().toISOString();
    return true;
  }

  async listFoods(): Promise<FoodItemRecord[]> {
    return [...this.foods.values()];
  }

  async searchFoods(_userId: string, query: string, barcode?: string): Promise<FoodItemRecord[]> {
    const normalized = normalizeText(query);
    return [...this.foods.values()].filter((food) => {
      if (barcode && food.barcode === barcode) return true;
      const canonical = food.canonicalName ? normalizeText(food.canonicalName) : food.normalizedName;
      return food.normalizedName.includes(normalized) ||
        normalized.includes(food.normalizedName) ||
        canonical.includes(normalized) ||
        normalized.includes(canonical);
    });
  }

  async upsertFoodItem(input: Omit<FoodItemRecord, "id">): Promise<FoodItemRecord> {
    const normalized = normalizeText(input.normalizedName || input.name);
    const existing = [...this.foods.values()].find((food) => {
      if (input.externalSource && input.externalId) {
        return food.externalSource === input.externalSource && food.externalId === input.externalId;
      }
      return food.userId === input.userId && food.normalizedName === normalized && food.source === input.source;
    });
    if (existing) {
      const updated = { ...existing, ...input, normalizedName: normalized };
      this.foods.set(existing.id, updated);
      return updated;
    }
    const food = { ...input, id: newId(), normalizedName: normalized };
    this.foods.set(food.id, food);
    return food;
  }

  async getNutritionTarget(userId: string): Promise<NutritionSnapshot> {
    return this.targets.get(userId) ?? { calories: 2200, proteinGrams: 160, carbsGrams: 240, fatGrams: 70 };
  }

  async listMeals(userId: string, limit = 25): Promise<Meal[]> {
    return [...this.meals.values()]
      .filter((meal) => meal.userId === userId && !meal.deletedAt)
      .sort((a, b) => Date.parse(b.occurredAt) - Date.parse(a.occurredAt))
      .slice(0, limit)
      .map(({ userId: _userId, ...meal }) => meal);
  }

  async getMeal(userId: string, mealId: string): Promise<Meal | undefined> {
    const meal = this.meals.get(mealId);
    if (!meal || meal.userId !== userId || meal.deletedAt) return undefined;
    const { userId: _userId, ...publicMeal } = meal;
    return publicMeal;
  }

  async createProposal(userId: string, proposal: Omit<MealProposal, "id" | "createdAt">): Promise<MealProposal> {
    const stored = { ...proposal, id: newId(), createdAt: new Date().toISOString(), userId };
    this.proposals.set(stored.id, stored);
    const { userId: _userId, ...publicProposal } = stored;
    return publicProposal;
  }

  async getProposal(userId: string, proposalId: string): Promise<MealProposal | undefined> {
    const proposal = this.proposals.get(proposalId);
    if (!proposal || proposal.userId !== userId) return undefined;
    const { userId: _userId, ...publicProposal } = proposal;
    return publicProposal;
  }

  async updateProposal(userId: string, proposal: MealProposal): Promise<MealProposal> {
    const existing = this.proposals.get(proposal.id);
    if (!existing || existing.userId !== userId) throw new Error("proposal_not_found");
    this.proposals.set(proposal.id, { ...proposal, userId });
    return proposal;
  }

  async createMealFromProposal(userId: string, proposal: MealProposal, occurredAt: string, items = proposal.items): Promise<Meal> {
    const nutrition = sumNutrition(items);
    const meal: Meal & { userId: string } = {
      id: newId(),
      title: proposal.title,
      occurredAt,
      nutrition,
      items,
      createdAt: new Date().toISOString(),
      userId
    };
    this.meals.set(meal.id, meal);
    const updatedProposal = { ...proposal, status: "committed" as const };
    await this.updateProposal(userId, updatedProposal);
    const { userId: _userId, ...publicMeal } = meal;
    return publicMeal;
  }

  async updateMeal(userId: string, meal: Meal): Promise<Meal> {
    const existing = this.meals.get(meal.id);
    if (!existing || existing.userId !== userId) throw new Error("meal_not_found");
    this.meals.set(meal.id, { ...meal, userId });
    return meal;
  }

  async softDeleteMeal(userId: string, mealId: string): Promise<boolean> {
    const meal = this.meals.get(mealId);
    if (!meal || meal.userId !== userId || meal.deletedAt) return false;
    meal.deletedAt = new Date().toISOString();
    return true;
  }

  async getDailySummary(userId: string, date: string): Promise<import("@cal-tracker/contracts").DailySummary> {
    const meals = (await this.listMeals(userId, 100)).filter((meal) => meal.occurredAt.slice(0, 10) === date);
    const consumed = meals.reduce((total, meal) => ({
      calories: total.calories + meal.nutrition.calories,
      proteinGrams: Math.round((total.proteinGrams + meal.nutrition.proteinGrams) * 10) / 10,
      carbsGrams: Math.round((total.carbsGrams + meal.nutrition.carbsGrams) * 10) / 10,
      fatGrams: Math.round((total.fatGrams + meal.nutrition.fatGrams) * 10) / 10
    }), { calories: 0, proteinGrams: 0, carbsGrams: 0, fatGrams: 0 });
    const target = await this.getNutritionTarget(userId);
    return { date, consumed, target, remaining: subtractNutrition(target, consumed), meals };
  }

  async listTemplates(userId: string): Promise<MealTemplate[]> {
    return [...this.templates.values()]
      .filter((template) => template.userId === userId)
      .map(({ userId: _userId, ...template }) => template);
  }

  async createTemplate(userId: string, input: Omit<MealTemplate, "id">): Promise<MealTemplate> {
    const stored = { ...input, id: newId(), userId };
    this.templates.set(stored.id, stored);
    for (const alias of input.aliases) {
      await this.createMemory({ userId, normalizedText: normalizeText(alias), label: alias, templateId: stored.id, confidence: 1 });
    }
    const { userId: _userId, ...template } = stored;
    return template;
  }

  async updateTemplate(userId: string, template: MealTemplate): Promise<MealTemplate> {
    const existing = this.templates.get(template.id);
    if (!existing || existing.userId !== userId) throw new Error("template_not_found");
    this.templates.set(template.id, { ...template, userId });
    return template;
  }

  async deleteTemplate(userId: string, templateId: string): Promise<boolean> {
    const existing = this.templates.get(templateId);
    if (!existing || existing.userId !== userId) return false;
    this.templates.delete(templateId);
    return true;
  }

  async queryMemory(userId: string, normalizedText: string): Promise<MemoryMatch[]> {
    const exact = [...this.memories.values()].filter((memory) => memory.userId === userId && memory.normalizedText === normalizedText);
    const fuzzy = [...this.memories.values()].filter(
      (memory) => memory.userId === userId && memory.normalizedText !== normalizedText &&
        (normalizedText.includes(memory.normalizedText) || memory.normalizedText.includes(normalizedText))
    );
    return [...exact, ...fuzzy].map((memory) => {
      const template = memory.templateId ? this.templates.get(memory.templateId) : undefined;
      return {
        id: memory.id,
        userId,
        label: memory.label,
        normalizedText: memory.normalizedText,
        confidence: exact.includes(memory) || normalizedText.includes(memory.normalizedText) ? memory.confidence : Math.min(memory.confidence, 0.82),
        template: template ? stripUserId(template) : null
      };
    });
  }

  async createMemory(input: { userId: string; normalizedText: string; label: string; templateId?: string; confidence: number }): Promise<void> {
    this.memories.set(`${input.userId}:${input.normalizedText}`, { id: newId(), usageCount: 0, ...input });
  }

  async recordActionCall(input: Omit<ActionCallRecord, "id" | "createdAt">): Promise<ActionCallRecord> {
    const record = { ...input, id: newId(), createdAt: new Date().toISOString() };
    this.actionCalls.push(record);
    return record;
  }

  async recordAuditEvent(input: Omit<AuditEventRecord, "id" | "createdAt">): Promise<AuditEventRecord> {
    const record = { ...input, id: newId(), createdAt: new Date().toISOString() };
    this.auditEvents.push(record);
    return record;
  }

  async listActionCalls(userId: string): Promise<ActionCallRecord[]> {
    return this.actionCalls.filter((call) => call.userId === userId);
  }

  async listAuditEvents(userId: string): Promise<AuditEventRecord[]> {
    return this.auditEvents.filter((event) => event.userId === userId);
  }

  private requireUser(userId: string): StoredUser {
    const user = this.users.get(userId);
    if (!user) throw new Error("user_not_found");
    return user;
  }

  private async createDefaultTemplate(userId: string): Promise<void> {
    const foods = [...this.foods.values()];
    const oats = foods.find((food) => food.normalizedName === "oats")!;
    const milk = foods.find((food) => food.normalizedName === "milk")!;
    const egg = foods.find((food) => food.normalizedName === "egg")!;
    const items: MealItem[] = [
      { name: oats.name, quantity: 60, unit: "g", calories: 233, proteinGrams: 10.1, carbsGrams: 39.8, fatGrams: 4.1, source: oats.source },
      { name: milk.name, quantity: 250, unit: "ml", calories: 122, proteinGrams: 8.1, carbsGrams: 12, fatGrams: 4.8, source: milk.source },
      { name: egg.name, quantity: 2, unit: "egg", calories: 144, proteinGrams: 12.6, carbsGrams: 0.8, fatGrams: 9.6, source: egg.source }
    ];
    await this.createTemplate(userId, {
      title: "Usual breakfast",
      trustedAutoCommitEnabled: false,
      nutrition: sumNutrition(items),
      items,
      aliases: ["usual breakfast", "normal breakfast"]
    });
  }
}

function stripUserId<T extends { userId: string }>(value: T): Omit<T, "userId"> {
  const { userId: _userId, ...rest } = value;
  return rest;
}
