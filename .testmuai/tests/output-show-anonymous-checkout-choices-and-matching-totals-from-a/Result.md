---
test: ../show-anonymous-checkout-choices-and-matching-totals-from-a_test.md
status: failed
started: 2026-09-10T09:36:50.478Z
duration_s: 311
session_id: 6b744ca9-abc8-406f-a24f-4ec19db2b37c
---

# Show anonymous checkout choices and matching totals from a non-empty cart — Result

## Step 1 ✓ passed (190.3s)
md5: adb0c6b087838f366acf9ff48b8bbfc9
On https://ecommerce-playground.lambdatest.io/ as an anonymous shopper, add two purchasable products so the cart contains two distinct items with differing quantities, then open the cart page.

## Step 2 ✓ passed (39s)
md5: 05c26c8cfab036432c59001678a97dd6
On the cart page, store the current surface as cart_page_baseline and capture each displayed monetary total that will also appear in checkout as cart_totals, then assert a checkout entry point is visible.

## Step 3 ✗ failed (77.7s)
md5: f7f9f2d7f03aff100bc5ee4864fb1423
Reason: Final verification failed: "checkout is opened, a guest checkout option is shown, a register/login option is shown, and every displayed monetary total that matches a captured cart total equals {{cart_totals}}" — bug verdict: Checkout total assertion ignores checkout shipping [automation_bug/state_transition_bug, confidence 0.90]
From the non-empty cart, activate checkout as an anonymous shopper and stop on the checkout entry surface, then assert checkout is opened, a guest checkout option is shown, a register/login option is shown, and every displayed monetary total that matches a captured cart total equals cart_totals.
