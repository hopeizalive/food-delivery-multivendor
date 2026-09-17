import { test, expect } from '@playwright/test';
import { login } from './utils';

// Update-only spec against the Commission Rate screen (/management/commission-rates):
// a paginated table of existing restaurants, each with its own inline-editable
// commission rate and its own row-level "Save" button - no create/edit-modal/delete
// here, so this operates against a seeded restaurant row instead of a fresh record.

test.describe('Commission Rate', () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
    await page.goto('/management/commission-rates');
  });

  test('update a restaurant commission rate', async ({ page }) => {
    const row = page.getByRole('row', { name: /Demo Bistro/ });
    await expect(row).toBeVisible({ timeout: 10000 });

    const input = row.locator('input[type="number"]');
    await input.fill('');
    await input.fill('15');

    const saveButton = row.getByRole('button', { name: 'Save' });
    await expect(saveButton).toBeEnabled({ timeout: 10000 });
    await saveButton.click();

    // Reload and confirm the new rate persisted server-side.
    await page.reload();
    const reloadedRow = page.getByRole('row', { name: /Demo Bistro/ });
    await expect(reloadedRow.locator('input[type="number"]')).toHaveValue('15', { timeout: 10000 });
  });
});
