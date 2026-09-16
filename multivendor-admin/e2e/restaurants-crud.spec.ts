import { test, expect } from '@playwright/test';
import {
  login,
  selectDropdownOption,
  selectMultiSelectOption,
  openRowMenu,
  fillPhoneNumber,
} from './utils';

// Full CRUD against the Restaurants (Stores) screen (/general/stores):
// create, status toggle, duplicate, hard delete. The "Location" and
// "Timing" wizard steps need Google Maps (no API key configured in this
// dev environment) so this only drives the two steps that actually create
// the restaurant (Set Vendor + Add Details) - CREATE_RESTAURANT already
// fires after step 2, so the record exists without completing the wizard.
//
// Assertions check table/tab state rather than toast text - see
// riders-crud.spec.ts for why (toasts auto-dismiss and raced Playwright's
// assertion timing).

test.describe('Restaurants CRUD', () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
    await page.goto('/general/stores');
  });

  test('create a restaurant, toggle status, duplicate, then hard delete', async ({ page }) => {
    test.setTimeout(60000);
    const suffix = Date.now();
    const storeName = `E2E Diner ${suffix}`;

    // ---- Create (step 1: pick the seeded vendor) ----
    await page.getByText('Add Store', { exact: true }).click();
    await selectDropdownOption(page, 'Select Vendor', 'vendor-demo@enatega.com');
    await page.getByRole('button', { name: 'Save & Next' }).click();

    // ---- Create (step 2: restaurant details) ----
    await page.getByPlaceholder('Name').fill(storeName);
    await page.getByPlaceholder('Email').fill(`e2e-diner-${suffix}@enatega.com`);
    await page.getByPlaceholder('Password', { exact: true }).fill('Demo1234!');
    await page.getByPlaceholder('Confirm Password').fill('Demo1234!');
    await fillPhoneNumber(page, '3001234567');
    await page.getByPlaceholder('Address').fill('1 E2E Test Street, Karachi');

    // useShopTypes() debounces its GET_SHOP_TYPES fetch by a flat 5s from
    // mount (lib/hooks/useLazyQueryQL.tsx), and re-renders while typing
    // above can push that further out - give it a clear, idle window before
    // opening the dropdown so it isn't still showing "No available options".
    await page.waitForTimeout(6000);
    await selectDropdownOption(page, 'Shop Category', 'Restaurant');
    await selectMultiSelectOption(page, 'Cuisines', 'Continental');
    await page.getByRole('button', { name: 'Save & Next' }).click();

    // Wizard moves to step 3 (Location, needs Google Maps) once
    // CREATE_RESTAURANT succeeds - that transition is enough proof of
    // success; close the sidebar rather than complete steps 3/4.
    await expect(page.getByText('Location', { exact: true })).toBeVisible({ timeout: 10000 });
    await page.keyboard.press('Escape');
    await expect(page.getByText(storeName)).toBeVisible({ timeout: 10000 });

    // ---- Toggle active/inactive status ----
    const row = page.getByRole('row', { name: new RegExp(storeName) });
    await expect(row.getByRole('checkbox')).toBeChecked(); // isActive: true by default
    await row.getByRole('checkbox').click({ force: true });
    await expect(row.getByRole('checkbox')).not.toBeChecked({ timeout: 10000 });

    // ---- Duplicate ----
    await openRowMenu(row);
    await page.getByRole('menuitem', { name: 'Duplicate' }).click();
    await selectDropdownOption(page, 'Select Vendor', 'vendor-demo@enatega.com');
    await page.getByRole('button', { name: 'Duplicate', exact: true }).click();
    await expect(page.getByRole('dialog', { name: 'Duplicate Store' })).not.toBeVisible({ timeout: 10000 });

    await page.getByText('Cloned', { exact: true }).click();
    await expect(page.getByText(`${storeName} (Copy)`)).toBeVisible({ timeout: 10000 });
    await page.getByText('Actual', { exact: true }).click();

    // ---- Hard delete ----
    await openRowMenu(row);
    await page.getByRole('menuitem', { name: 'Delete' }).click();
    await page.getByRole('button', { name: 'Confirm', exact: true }).click();
    await expect(row).not.toBeVisible({ timeout: 10000 });
  });
});
