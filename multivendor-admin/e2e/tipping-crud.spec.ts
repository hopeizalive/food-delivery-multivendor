import { test, expect } from '@playwright/test';
import { login } from './utils';

// Update-only spec against the Tipping screen (/management/tippings): this is
// a single global config record edited inline on the page - no Add button, no
// modal, no list. mock-api seeds a `tips` record, so the submit button always
// reads "Update" here (it only reads "Add" when data.tips._id is falsy).

test.describe('Tipping', () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
    await page.goto('/management/tippings');
  });

  test('update tip variations', async ({ page }) => {
    const tip1 = page.getByPlaceholder('Tip 1 eg 10');
    const tip2 = page.getByPlaceholder('Tip 2 eg 20');
    const tip3 = page.getByPlaceholder('Tip 3 eg 30');

    await expect(tip1).toBeVisible({ timeout: 10000 });

    await tip1.fill('');
    await tip1.fill('11');
    await tip2.fill('');
    await tip2.fill('22');
    await tip3.fill('');
    await tip3.fill('33');

    await page.getByRole('button', { name: 'Update', exact: true }).click();

    // Reload and confirm the new values persisted server-side rather than
    // trusting toast text (wording/timing not confirmed for this screen).
    await page.reload();
    await expect(page.getByPlaceholder('Tip 1 eg 10')).toHaveValue('11', { timeout: 10000 });
    await expect(page.getByPlaceholder('Tip 2 eg 20')).toHaveValue('22');
    await expect(page.getByPlaceholder('Tip 3 eg 30')).toHaveValue('33');
  });
});
