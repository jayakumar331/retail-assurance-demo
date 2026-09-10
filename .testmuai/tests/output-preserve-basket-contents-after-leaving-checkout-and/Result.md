---
test: ../preserve-basket-contents-after-leaving-checkout-and_test.md
status: passed
started: 2026-09-10T09:28:15.529Z
duration_s: 485
session_id: f37189e8-2f19-409a-a6ac-0f37b94857eb
---

# Preserve basket contents after leaving checkout and returning — Result

## Step 1 ✓ passed (158.4s)
md5: adb0c6b087838f366acf9ff48b8bbfc9
On https://ecommerce-playground.lambdatest.io/ as an anonymous shopper, add two purchasable products so the cart contains two distinct items with differing quantities, then open the cart page.

## Step 2 ✓ passed (57.2s)
md5: fa59745ab63bee2a9b1498f27023c344
On the cart page, store the current surface as cart_page_baseline, capture the basket item names and quantities as basket_before_leave, and capture each displayed monetary total that will also appear in checkout as cart_totals, then assert a checkout entry point is visible.

## Step 3 ✓ passed (94.2s)
md5: 61021da306df835cc19aba7f1aea376f
From the non-empty cart, activate checkout and stop on the checkout entry surface, then assert checkout is opened and every displayed monetary total that matches a captured cart total equals cart_totals.

## Step 4 ✓ passed (132.5s)
md5: e67156fc9a68abe84e7dd29990f2809b
Leave checkout by opening another storefront page, then return to checkout through the cart flow, then assert the basket items and quantities equal basket_before_leave.
