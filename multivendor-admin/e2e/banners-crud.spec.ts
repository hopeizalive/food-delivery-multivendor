import path from 'path';
import { test, expect } from '@playwright/test';
import { login, selectDropdownOption, openRowMenu } from './utils';

// Full CRUD against the Banners screen (/management/banners): create, edit,
// delete. Banner form requires a real file upload (image or video), same
// mock-api uploadImageToS3 pattern as vendors/cuisines. "Screen" options
// depend on the "Actions" choice - using "Navigate To Specific Page" keeps
// the Screen dropdown's options static (no dependency on seeded restaurant data).

const TEST_IMAGE = path.join(__dirname, 'fixtures', 'test-image.png');

test.describe('Banners CRUD', () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
    await page.goto('/management/banners');
  });

  test('create, edit, then delete a banner', async ({ page }) => {
    const suffix = Date.now();
    const title = `E2E Banner ${suffix}`;
    const updatedTitle = `E2E Banner ${suffix} Updated`;

    // ---- Create ----
    await page.getByText('Add Banner', { exact: true }).click();
    await page.getByPlaceholder('Title', { exact: true }).fill(title);
    await page.getByPlaceholder('Description', { exact: true }).fill('E2E test banner description');
    await selectDropdownOption(page, 'Actions', 'Navigate To Specific Page');
    await selectDropdownOption(page, 'Screen', 'Near By Restaurants');
    await page.locator('input[type="file"]').first().setInputFiles(TEST_IMAGE);
    await expect(page.getByText('has been uploaded successfully')).toBeVisible({ timeout: 10000 });
    await page.getByRole('button', { name: 'Add', exact: true }).click();
    await expect(page.getByPlaceholder('Title', { exact: true })).not.toBeVisible({ timeout: 10000 });

    const row = page.getByRole('row', { name: new RegExp(title) });
    await expect(row).toBeVisible({ timeout: 10000 });

    // ---- Edit ----
    await openRowMenu(row);
    await page.getByRole('menuitem', { name: 'Edit' }).click();
    const titleField = page.getByPlaceholder('Title', { exact: true });
    await expect(titleField).toHaveValue(title, { timeout: 10000 });
    await titleField.fill('');
    await titleField.fill(updatedTitle);
    await page.getByRole('button', { name: 'Update', exact: true }).click();
    await expect(titleField).not.toBeVisible({ timeout: 10000 });

    const updatedRow = page.getByRole('row', { name: new RegExp(updatedTitle) });
    await expect(updatedRow).toBeVisible({ timeout: 10000 });

    // ---- Delete ----
    await openRowMenu(updatedRow);
    await page.getByRole('menuitem', { name: 'Delete' }).click();
    await page.getByRole('button', { name: 'Confirm', exact: true }).click();

    await expect(updatedRow).not.toBeVisible({ timeout: 10000 });
  });
});
