---
tags: [recovered, checkout]
---
# Take a signed-in shopper directly into checkout from a non-empty cart

> Recovered from kane-cli design run design-20260910T081643-714f (uc-3, 2026-09-10). Not linked to the current assurance store; @verifies tags were removed because the original ac-N ids no longer exist.

## Step 1

On https://ecommerce-playground.lambdatest.io/, sign in with {{registered_email}} and {{registered_password}} and reach a signed-in storefront page where the header shows My Account or Logout.

## Step 2

On the storefront as the signed-in shopper, add one purchasable product to the cart and open the cart page.

## Step 3

On the cart page, store the current surface as cart_page_baseline and capture each displayed monetary total that will also appear in checkout as cart_totals, then assert a checkout entry point is visible.

## Step 4

From the non-empty cart, activate checkout as the signed-in shopper, then assert checkout is opened, no guest checkout or register/login choice step is shown before checkout, and every displayed monetary total that matches a captured cart total equals cart_totals.
