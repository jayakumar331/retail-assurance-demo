---
tags: [recovered, checkout]
---
# Show anonymous checkout choices and matching totals from a non-empty cart

> Recovered from kane-cli design run design-20260910T081643-714f (uc-3, 2026-09-10). Not linked to the current assurance store; @verifies tags were removed because the original ac-N ids no longer exist.

## Step 1

On https://ecommerce-playground.lambdatest.io/ as an anonymous shopper, add two purchasable products so the cart contains two distinct items with differing quantities, then open the cart page.

## Step 2

On the cart page, store the current surface as cart_page_baseline and capture each displayed monetary total that will also appear in checkout as cart_totals, then assert a checkout entry point is visible.

## Step 3

From the non-empty cart, activate checkout as an anonymous shopper and stop on the checkout entry surface, then assert checkout is opened, a guest checkout option is shown, a register/login option is shown, and every displayed monetary total that matches a captured cart total equals cart_totals.
