import path from 'path';
import { test, expect } from '@playwright/test';
import { login, selectDropdownOption, openRowMenu } from './utils';

// Full CRUD against the Cuisines screen (/management/cuisines): create, edit,
// delete. CuisineFormSchema requires a real image upload (no placeholder
// default like Shop Types/Restaurants), so this reuses the upload pattern from
// vendors-crud.spec.ts against mock-api's uploadImageToS3 mutation.

const TEST_IMAGE = path.join(__dirname, 'fixtures', 'test-image.png');

test.describe('Cuisines CRUD', () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
    await page.goto('/management/cuisines');
  });

  test('create, edit, then delete a cuisine', async ({ page }) => {
    const suffix = Date.now();
    const name = `E2E Cuisine ${suffix}`;
    const updatedName = `E2E Cuisine ${suffix} Updated`;

    // ---- Create ----
    await page.getByText('Add Cuisines', { exact: true }).click();
    await page.getByPlaceholder('Name', { exact: true }).fill(name);
    await page.getByPlaceholder('Description', { exact: true }).fill('E2E test cuisine description');
    await selectDropdownOption(page, 'Shop Category', 'Restaurant');
    await page.locator('input[type="file"]').first().setInputFiles(TEST_IMAGE);
    await expect(page.getByText('has been uploaded successfully')).toBeVisible({ timeout: 10000 });
    await page.getByRole('button', { name: 'Add', exact: true }).click();
    await expect(page.getByPlaceholder('Name', { exact: true })).not.toBeVisible({ timeout: 10000 });

    const row = page.getByRole('row', { name: new RegExp(name) });
    await expect(row).toBeVisible({ timeout: 10000 });

    // ---- Edit ----
    await openRowMenu(row);
    await page.getByRole('menuitem', { name: 'Edit' }).click();
    const nameField = page.getByPlaceholder('Name', { exact: true });
    await expect(nameField).toHaveValue(name, { timeout: 10000 });
    await nameField.fill('');
    await nameField.fill(updatedName);
    await page.getByRole('button', { name: 'Update', exact: true }).click();
    await expect(nameField).not.toBeVisible({ timeout: 10000 });

    const updatedRow = page.getByRole('row', { name: new RegExp(updatedName) });
    await expect(updatedRow).toBeVisible({ timeout: 10000 });

    // ---- Delete ----
    await openRowMenu(updatedRow);
    await page.getByRole('menuitem', { name: 'Delete' }).click();
    await page.getByRole('button', { name: 'Confirm', exact: true }).click();

    await expect(updatedRow).not.toBeVisible({ timeout: 10000 });
  });
});
