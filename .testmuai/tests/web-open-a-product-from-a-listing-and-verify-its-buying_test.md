---
assurance:
  id: t-3
  base: sha256:a87274f50cdf19ec75c598e34aa79631dffb72a7c1fded68f73a6a7e52d554a2
---
# Web: open a product from a listing and verify its buying information is shown

> Prove that opening a product from a listing reveals the product information a shopper needs to decide whether to buy.

## Step 1

At {{start_url}}, open a product listing and open any listed product from that page.

## Step 2 @verifies ac-13, ac-14, ac-15, ac-16

On the product detail page for the opened product, inspect the product summary and purchase section, then assert the product name, product price, availability, and a quantity field are shown.
