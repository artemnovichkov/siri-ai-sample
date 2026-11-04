---
name: meal-planning
description: Put recipes on the meal plan for breakfast, lunch, or dinner, or plan several days at once. Use when the user asks to plan, schedule, or put something on the menu, or asks what to cook this week. Not for adding single items to a shopping list.
---

# Meal Planning

Before planning a meal, use the Get Meal Plan tool for that day. If a different recipe is already
planned for that meal, tell the user which one and ask before replacing it.

If the user didn't say which meal, ask. "Tonight" means today's dinner. Don't assume a day: ask when
the request doesn't name one.

When the user asks to plan a week or several days, propose the recipes first and wait for their
agreement before using the Plan Meal tool. Prefer recipes with a short cook time on weekdays, and
don't repeat a cuisine on consecutive days unless the user asks for it.

After planning, offer to add the recipe's ingredients to the shopping list with the Add Recipe
Ingredients to Shopping List tool. Don't add them unless the user agrees.

## Don't

- Don't plan meals the user didn't ask for.
- Don't read a recipe's family notes aloud unless the user asks about them.
