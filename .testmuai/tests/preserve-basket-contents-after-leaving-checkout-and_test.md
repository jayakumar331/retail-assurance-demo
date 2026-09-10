---
tags: [recovered, checkout]
---
# Preserve basket contents after leaving checkout and returning

> Recovered from kane-cli design run design-20260910T081643-714f (uc-3, 2026-09-10). Not linked to the current assurance store; @verifies tags were removed because the original ac-N ids no longer exist.

## Step 1

On https://ecommerce-playground.lambdatest.io/ as an anonymous shopper, add two purchasable products so the cart contains two distinct items with differing quantities, then open the cart page.

## Step 2

On the cart page, store the current surface as cart_page_baseline, capture the basket item names and quantities as basket_before_leave, and capture each displayed monetary total that will also appear in checkout as cart_totals, then assert a checkout entry point is visible.

## Step 3

From the non-empty cart, activate checkout and stop on the checkout entry surface, then assert checkout is opened and every displayed monetary total that matches a captured cart total equals cart_totals.

## Step 4

Leave checkout by opening another storefront page, then return to checkout through the cart flow, then assert the basket items and quantities equal basket_before_leave.
