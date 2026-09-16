import path from 'path';
import { test, expect } from '@playwright/test';
import { login, fillPhoneNumber } from './utils';

// Full CRUD against the Vendors screen (/general/vendors): create, edit,
// delete. The vendor form requires a real image upload (VendorSchema has
// no default placeholder URL like the restaurant form does), backed here by
// mock-api's uploadImageToS3 mutation (returns a placeholder picsum.photos
// URL instead of a real S3 upload - see mock-api/src/resolvers.js).
// Delete is gated behind ISPAID_VERSION client-side, which the mock's
// configuration resolver now reports as true.

const TEST_IMAGE = path.join(__dirname, 'fixtures', 'test-image.png');

test.describe('Vendors CRUD', () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
    await page.goto('/general/vendors');
  });

  test('create, edit, then delete a vendor', async ({ page }) => {
    const suffix = Date.now();
    const firstName = 'E2E';
    const lastName = `Vendor${suffix}`;
    const email = `e2e-vendor-${suffix}@enatega.com`;
    const updatedLastName = `Vendor${suffix}Updated`;

    // ---- Create ----
    await page.getByText('Add Vendor', { exact: true }).click();
    await page.getByPlaceholder('First Name').fill(firstName);
    await page.getByPlaceholder('Last Name').fill(lastName);
    await page.getByPlaceholder('Email').fill(email);
    await fillPhoneNumber(page, '3001234567');
    await page.getByPlaceholder('Password', { exact: true }).fill('Demo1234!');
    await page.getByPlaceholder('Confirm Password').fill('Demo1234!');
    await page.locator('input[type="file"]').first().setInputFiles(TEST_IMAGE);
    await expect(page.getByText('has been uploaded successfully')).toBeVisible({ timeout: 10000 });
    await page.getByRole('button', { name: 'Add', exact: true }).click();

    await expect(page.getByText('Vendor has been added successfully')).toBeVisible({ timeout: 10000 });
    await expect(page.getByText(`${firstName} ${lastName}`)).toBeVisible({ timeout: 10000 });

    // ---- Edit ----
    await page.getByText(`${firstName} ${lastName}`).click();
    await page.locator('.three-dots svg').click();
    await page.getByText('Edit', { exact: true }).click();

    const lastNameField = page.getByPlaceholder('Last Name');
    await expect(lastNameField).toHaveValue(lastName, { timeout: 10000 });
    await lastNameField.fill('');
    await lastNameField.fill(updatedLastName);
    await page.getByRole('button', { name: 'Update', exact: true }).click();

    await expect(page.getByText('Vendor has been edited successfully')).toBeVisible({ timeout: 10000 });
    await expect(page.getByText(`${firstName} ${updatedLastName}`)).toBeVisible({ timeout: 10000 });

    // ---- Delete ----
    await page.getByText(`${firstName} ${updatedLastName}`).click();
    await page.locator('.three-dots svg').click();
    await page.getByText('Delete', { exact: true }).click();
    await page.getByRole('button', { name: 'Confirm', exact: true }).click();

    await expect(page.getByText('Vendor has been deleted successfully')).toBeVisible({ timeout: 10000 });
    await expect(page.getByText(`${firstName} ${updatedLastName}`)).not.toBeVisible({ timeout: 10000 });
  });
});
