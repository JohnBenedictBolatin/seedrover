import { test, expect } from '@playwright/test';
import { accounts, asRole, evidence } from '../support';

test.beforeEach(async ({ page }) => { await asRole(page, 'admin'); });

test('SR-ROVIE-001 Clear conversation removes saved history for the signed-in account', async ({ page }, info) => {
  const profileId = accounts().admin.id;
  const oldText = 'AUTOTEST old Rovie conversation';
  await page.goto('/dashboard');
  await page.evaluate(({ profileId, oldText }) => {
    localStorage.setItem(`seedrover-rovie-history:${profileId}`, JSON.stringify([
      { role: 'user', content: oldText },
      { role: 'assistant', content: 'AUTOTEST old Rovie answer' },
    ]));
  }, { profileId, oldText });

  await page.getByRole('button', { name: 'Open Rovie assistant' }).click();
  await expect(page.getByText(oldText)).toBeVisible();
  await page.getByRole('button', { name: 'Clear conversation' }).click();
  await expect(page.getByText(oldText)).toHaveCount(0);
  await expect(page.getByText(/Hi, I'm Rovie/)).toBeVisible();
  await expect.poll(() => page.evaluate((id) => localStorage.getItem(`seedrover-rovie-history:${id}`), profileId)).toBe('[]');
  await evidence(page, info, 'rovie-conversation-cleared');
});
