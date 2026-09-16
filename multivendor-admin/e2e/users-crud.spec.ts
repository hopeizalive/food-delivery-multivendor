import { test, expect } from '@playwright/test';
import { login } from './utils';

// CRUD-equivalent actions against the Users screen (/general/users): users
// have no create/edit form (they self-register via the customer app), but
// the admin exposes block/activate, reset-session, internal-notes, and
// delete via a per-row action menu (ActionMenu.tsx) - this exercises all
// four against the seeded "Sara Khan" user (status: active), leaving "Demo
// Customer" alone since other specs/manual testing may depend on it.

test.describe('Users actions', () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
    await page.goto('/general/users');
    await expect(page.getByText('Sara Khan')).toBeVisible({ timeout: 15000 });
  });

  test('block, reset session, edit notes, then delete a user', async ({ page }) => {
    const row = page.getByRole('row', { name: /Sara Khan/ });
    const actionsButton = row.getByRole('button', { name: 'Actions' });

    // ---- Block (status -> blocked) ----
    await actionsButton.click();
    await page.getByRole('menuitem', { name: 'Block User' }).click();
    await page.getByLabel('Reason').fill('E2E test: blocking for CRUD spec verification');
    await page.getByRole('button', { name: 'Yes, block' }).click();
    await expect(page.getByText(/User status updated to blocked/)).toBeVisible({ timeout: 10000 });

    // ---- Reset session ----
    await actionsButton.click();
    await page.getByRole('menuitem', { name: 'Reset Session' }).click();
    await page.getByRole('button', { name: 'Yes, reset' }).click();
    await expect(page.getByText('User session reset successfully')).toBeVisible({ timeout: 10000 });

    // ---- Internal note ----
    await actionsButton.click();
    await page.getByRole('menuitem', { name: 'Internal Note' }).click();
    await page.getByPlaceholder('Add internal notes here...').fill('E2E test note');
    await page.getByRole('button', { name: 'Save', exact: true }).click();
    await expect(page.getByText('User notes updated successfully')).toBeVisible({ timeout: 10000 });

    // ---- Delete ----
    await actionsButton.click();
    await page.getByRole('menuitem', { name: 'Delete Account' }).click();
    await page.getByRole('button', { name: 'Yes, delete' }).click();
    await expect(page.getByText('User deleted successfully')).toBeVisible({ timeout: 10000 });
    await expect(page.getByText('Sara Khan')).not.toBeVisible({ timeout: 10000 });
  });
});
