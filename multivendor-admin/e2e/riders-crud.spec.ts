import { test, expect } from '@playwright/test';
import { login, selectDropdownOption, openRowMenu, fillPhoneNumber } from './utils';

// Full CRUD against the Riders screen (/general/riders): create, edit,
// availability toggle, delete. Unlike restaurants/vendors, the rider form
// needs no image upload and no Google Maps interaction, so this is testable
// end-to-end without any mocked-out steps.
//
// Assertions check table state (row present/absent, checkbox checked) rather
// than toast text - the success toasts here auto-dismiss after 3s, which
// made assertions on them flaky under Playwright's retry timing.

test.describe('Riders CRUD', () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
    await page.goto('/general/riders');
  });

  test('create, edit, toggle availability, then delete a rider', async ({ page }) => {
    const suffix = Date.now();
    const riderName = `E2E Rider ${suffix}`;
    const username = `e2e-rider-${suffix}`;
    const updatedName = `E2E Rider ${suffix} Updated`;

    // ---- Create ----
    await page.getByText('Add Rider', { exact: true }).click();
    await page.getByPlaceholder('Name', { exact: true }).fill(riderName);
    await page.getByPlaceholder('Username').fill(username);
    await page.getByPlaceholder('Password', { exact: true }).fill('Demo1234!');
    await page.getByPlaceholder('Confirm Password').fill('Demo1234!');
    await selectDropdownOption(page, 'Vehicle Type', 'Bicycle');
    await selectDropdownOption(page, 'Zone', 'Karachi');
    await fillPhoneNumber(page, '3001234567');
    await page.getByRole('button', { name: 'Add', exact: true }).click();

    // Wait for the sidebar to actually close (it stays open, and its mask
    // keeps intercepting clicks, until the create mutation + refetch +
    // onHide() finish) before touching the table underneath it.
    await expect(page.getByPlaceholder('Name', { exact: true })).not.toBeVisible({ timeout: 10000 });

    const row = page.getByRole('row', { name: new RegExp(riderName) });
    await expect(row).toBeVisible({ timeout: 10000 });
    await expect(row.getByRole('checkbox')).toBeChecked(); // available: true by default

    // ---- Edit ----
    await openRowMenu(row);
    await page.getByRole('menuitem', { name: 'Edit' }).click();
    const nameField = page.getByPlaceholder('Name', { exact: true });
    await expect(nameField).toHaveValue(riderName, { timeout: 10000 });
    await nameField.fill('');
    await nameField.fill(updatedName);
    // RiderSchema requires password/confirmPassword on edit too (they're
    // never prefilled from the existing rider - see e2e/README.md) so the
    // form silently fails validation and never submits without these.
    await page.getByPlaceholder('Password', { exact: true }).fill('Demo1234!');
    await page.getByPlaceholder('Confirm Password').fill('Demo1234!');
    await page.getByRole('button', { name: 'Update' }).click();
    await expect(page.getByPlaceholder('Name', { exact: true })).not.toBeVisible({ timeout: 10000 });

    const updatedRow = page.getByRole('row', { name: new RegExp(updatedName) });
    await expect(updatedRow).toBeVisible({ timeout: 10000 });

    // ---- Toggle availability ----
    await updatedRow.getByRole('checkbox').click({ force: true });
    await expect(updatedRow.getByRole('checkbox')).not.toBeChecked({ timeout: 10000 });

    // ---- Delete ----
    await openRowMenu(updatedRow);
    await page.getByRole('menuitem', { name: 'Delete' }).click();
    await page.getByRole('button', { name: 'Confirm', exact: true }).click();

    await expect(updatedRow).not.toBeVisible({ timeout: 10000 });
  });
});
