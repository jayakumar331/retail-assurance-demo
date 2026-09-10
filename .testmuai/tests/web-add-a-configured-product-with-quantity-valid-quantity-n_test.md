---
assurance:
  id: t-1
  base: sha256:684d109ea8e0a683572c610963eb06faa15911c45234d1bedb9a0d2970ae004a
---
# Web: add a configured product with quantity {{valid_quantity_n}} and confirm cart count, subtotal, and quantity carry over

> Prove that a shopper can add a valid product after selecting required options, receive a success confirmation, see the header cart signals update, and have the entered non-1 quantity carry into the cart exactly.

## Step 1

At {{start_url}}, open a product listing that contains {{product_with_required_options}}; store the current header cart item count as baseline_header_count and the current header cart subtotal as baseline_header_subtotal, then open {{product_with_required_options}} from that listing.

## Step 2 @verifies ac-16

On the product detail page for {{product_with_required_options}}, in the purchase section, select every required option and enter {{valid_quantity_n}} in the quantity field, then assert the quantity field is present and shows {{valid_quantity_n}}.

## Step 3 @verifies ac-17, ac-12

From the same purchase section, add the configured product to the cart, then assert the add completes successfully and a success confirmation is shown.

## Step 4 @verifies ac-7, ac-8, ac-9

Open the cart and inspect the line for {{product_with_required_options}}, then assert the cart quantity equals {{valid_quantity_n}}, the header cart item count equals baseline_header_count plus {{valid_quantity_n}}, and the header cart subtotal equals the cart subtotal shown on the cart page.
