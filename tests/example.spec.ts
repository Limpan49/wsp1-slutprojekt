import { test, expect } from '@playwright/test';

test('has title', async ({ page }) => {
  await page.goto('localhost:9292');
  await page.getByText('Logga in').click(); // Hittar 'logga in' knappen

  await page.getByPlaceholder('Användarnamn').fill('Anonym123'); // Fyller i fälten
  await page.getByPlaceholder('Lösenord').fill('1234');

  await page.getByRole('button').click(); // Logga in


  // Expect a title "to contain" a substring.
  await expect(page.getByText('Inloggad som Anonym123')).toBeVisible(); // LEtar efter 'inloggad som anonym123'
});

test('get started link', async ({ page }) => {
  await page.goto('https://playwright.dev/');

  // Click the get started link.
  await page.getByRole('link', { name: 'Get started' }).click();

  // Expects page to have a heading with the name of Installation.
  await expect(page.getByRole('heading', { name: 'Installation' })).toBeVisible();
});
