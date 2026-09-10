---
test: ../take-a-signed-in-shopper-directly-into-checkout-from-a-non_test.md
status: passed
started: 2026-09-10T09:44:13.382Z
duration_s: 387
session_id: 40eb2ff9-9573-4e87-b65c-d0d5de5ccfe3
---

# Take a signed-in shopper directly into checkout from a non-empty cart — Result

## Step 1 ✓ passed (109.6s)
md5: 6a534d183f3d00a74de9560d556b9020
On https://ecommerce-playground.lambdatest.io/, sign in with {{registered_email}} and {{registered_password}} and reach a signed-in storefront page where the header shows My Account or Logout.

## Step 2 ✓ passed (118s)
md5: 200f01bfa032d5df06eb9834478eddc0
On the storefront as the signed-in shopper, add one purchasable product to the cart and open the cart page.

## Step 3 ✓ passed (62.3s)
md5: 05c26c8cfab036432c59001678a97dd6
On the cart page, store the current surface as cart_page_baseline and capture each displayed monetary total that will also appear in checkout as cart_totals, then assert a checkout entry point is visible.

## Step 4 ✓ passed (93.1s)
md5: cdc8bbc416e8dc5345a2da00a248b80f
From the non-empty cart, activate checkout as the signed-in shopper, then assert checkout is opened, no guest checkout or register/login choice step is shown before checkout, and every displayed monetary total that matches a captured cart total equals cart_totals.
