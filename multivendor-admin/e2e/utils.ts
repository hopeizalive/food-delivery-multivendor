import { expect, type Locator, type Page } from '@playwright/test';

// Shared helpers for the CRUD spec files (restaurants/riders/vendors/users).
// Each spec creates its own uniquely-named records (via Date.now()) so
// repeated runs against the same mock-api instance don't collide.

export async function login(page: Page) {
  await page.goto('/authentication/login');
  await page.getByPlaceholder('Email').fill('admin-demo@enatega.com');
  await page.getByPlaceholder('Password').fill('demo1234');
  await page.getByRole('button', { name: 'Login' }).click();
  await expect(page).toHaveURL(/\/home/, { timeout: 15000 });
}

// Opens a PrimeReact Dropdown by its placeholder/label text and picks an
// option. `container` scopes the initial click when the same placeholder
// text could match more than one dropdown on the page.
export async function selectDropdownOption(
  page: Page,
  placeholder: string,
  optionLabel: string
) {
  await page
    .locator('.p-dropdown')
    .filter({ hasText: placeholder })
    .first()
    .click();
  // Some dropdowns (e.g. Shop Category - useShopTypes has a fixed 5s
  // debounce before it fires GET_SHOP_TYPES) show "No available options"
  // for a few seconds after opening - give the panel time to repopulate
  // once the query resolves rather than failing on the empty state.
  await page
    .getByRole('option', { name: optionLabel, exact: false })
    .first()
    .click({ timeout: 15000 });
}

export async function selectMultiSelectOption(
  page: Page,
  placeholder: string,
  optionLabel: string
) {
  // CustomMultiSelectComponent renders a standalone <label>{placeholder}</label>
  // next to the actual .p-multiselect control (both inside one wrapper div) -
  // the label stays put after a selection is made, unlike the multiselect's
  // own displayed text (which PrimeReact swaps for the selected chip(s)), so
  // it's a stable anchor for both opening and closing the panel.
  const label = page.getByText(placeholder, { exact: true }).first();
  const wrapper = label.locator('xpath=..');
  await wrapper.locator('.p-multiselect').click();
  await page.getByRole('option', { name: optionLabel, exact: false }).first().click();
  // Close the panel by clicking that label, not Escape and not an outside
  // click - both bubble to / land on the enclosing PrimeReact Sidebar's
  // dismiss handling (closeOnEscape / dismissable both default true) and
  // close the whole wizard, discarding the in-progress form. Clicking inside
  // the Sidebar but outside the panel avoids that.
  await label.click();
}

// CustomPhoneTextField (react-international-phone) doesn't forward a
// `placeholder` prop to its <input> - the "Phone Number" text is only the
// field's <label>, so getByPlaceholder never matches it. Its own library
// CSS class is the stable selector instead.
export async function fillPhoneNumber(page: Page, value: string) {
  await page.locator('input.react-international-phone-input').first().fill(value);
}

// Opens the row-level "..." ActionMenu (ellipsis button) - shared by the
// riders/restaurants/vendors tables (users uses a differently-styled but
// equivalent button, see users-crud.spec.ts).
export async function openRowMenu(row: Locator) {
  await row.locator('button[aria-haspopup="true"]').click();
}
