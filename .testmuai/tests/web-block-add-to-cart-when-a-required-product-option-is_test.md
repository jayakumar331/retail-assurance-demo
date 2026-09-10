---
assurance:
  id: t-2
  base: sha256:7766d66a3d9ff42eb745d4d904f2a6dce35a5b837e4c5ef544ab2887546cb294
---
# Web: block add to cart when a required product option is missing

> Prove that add to cart is blocked until required options are selected and that the shopper is told which required option is missing.

## Step 1

At {{start_url}}, open a product listing that contains {{product_with_required_options}} and open {{product_with_required_options}} from that listing.

## Step 2 @verifies ac-10, ac-11

On the product detail page for {{product_with_required_options}}, leave one required option unselected and attempt to add the product to the cart, then assert the page identifies the specific missing required option and no successful add-to-cart completion is shown.
