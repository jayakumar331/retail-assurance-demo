# Test data for the retail storefront

Some designed steps describe their data in words instead of naming a variable. When a step
asks for one of these, use the variable given here. Never invent an account or an address.

| When a step says… | Use |
|---|---|
| valid / existing / registered credentials, or "sign in" as a known shopper | email `{{registered_email}}`, password `{{registered_password}}` |
| valid unique registration details, or a new shopper | first name `{{new_first_name}}`, last name `{{new_last_name}}`, email `{{new_email}}`, telephone `{{new_telephone}}`, password and confirm `{{new_password}}`, and tick the privacy policy unless the step says otherwise |
| a known email with a wrong password | email `{{existing_email}}`, password `{{wrong_password}}` |
| an email that is not registered | `{{unknown_email}}` |
| a malformed or invalid email address | `{{invalid_email}}` |
| a valid email for the newsletter / subscribe control | `{{newsletter_email}}` |
| a different currency | `{{target_currency}}` |
| a product with required options | `{{product_with_required_options}}` — its required option is `{{required_option_name}}` |
| a product to add to the cart, or two different ones | `{{cart_product_a}}`, then `{{cart_product_b}}` — neither has options |
| a product to search for | `{{search_term}}` |
| a search term that matches nothing | `{{no_match_term}}` |
