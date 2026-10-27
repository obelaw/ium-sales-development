# Domain Invariants & Exceptions Playbook

This reference provides exhaustive definitions for the 5 fundamental domain invariants ("The Law") enforced by `ium-sales`, detailing the conditions that trigger exceptions, structural consequences, and recommended recovery paths.

---

## 1. Domain Invariants Summary Table

| Invariant | Name | Enforced In | Exception Thrown |
| :--- | :--- | :--- | :--- |
| **Invariant 1** | Order Financial Balance Rule | `PricingEngineService`, `OrderService::confirm` | `InvalidFinancialBalanceException` |
| **Invariant 2** | The Price-Lock Law (Immutability) | `SalesOrder::booted`, `SalesOrderLine::booted` | `OrderPriceLockedException` |
| **Invariant 3** | Stock Allocation Rule (ATP Verified) | `FulfillmentService::allocate` | `InsufficientInventoryException` |
| **Invariant 4** | Split & Cancellation Governance | `OrderService::cancel` | `CannotCancelReleasedOrderException` |
| **Invariant 5** | RMA Quantity Integrity | `RmaService::request` | `InvalidRmaQuantityException` |

---

## 2. Invariant 1: Order Financial Balance Rule

### The Law
$$\text{Grand Total} = \sum(\text{Line Prices} - \text{Discounts}) + \text{Taxes} + \text{Shipping Fees}$$

- **Condition**: An order or quotation cannot transition to `Confirmed` if the computed sum of line items (after discounts), taxes, and shipping fees differs from the declared `grand_total` by more than `0.01`.
- **Exception**: `Obelaw\Ium\Sales\Exceptions\InvalidFinancialBalanceException`
- **Why It Matters**: Prevents accounting discrepancies, customer overbilling, and invoicing mismatches with external payment processors.
- **Recovery Path**: Recompute financials using `ium()->sales()->pricing()->computeOrderFinancials($lines, $shipping)` before submitting or confirming the order.

---

## 3. Invariant 2: "The Price-Lock Law" (Pricing Immutability)

### The Law
Once a `SalesOrder` transitions to `Confirmed`, its commercial terms (`unit_price`, `quantity`, `discount_amount`, `tax_rate`, `tax_amount`, `shipping_total`, `grand_total`, `currency`) are permanently frozen.

- **Condition**: Any Eloquent `update()` modifying price attributes or any `delete()` call on a confirmed order or its lines.
- **Exception**: `Obelaw\Ium\Sales\Exceptions\OrderPriceLockedException`
- **Why It Matters**: A confirmed order represents a legally binding commercial agreement and revenue commitment. Post-confirmation edits corrupt general ledger postings and tax compliance.
- **Recovery Path**:
  - To increase order quantities: Create a **Supplementary Order** linked via metadata.
  - To reduce price or provide discounts: Issue a **Credit Note** through Accounting / FMS.
  - To handle defective or unwanted goods: Initiate a **Return Merchandise Authorization (RMA)**.

---

## 4. Invariant 3: Stock Allocation Rule

### The Law
Hard allocation cannot occur without verified Available-To-Promise (ATP) stock at the target sourcing node.

- **Condition**: `requested_quantity > available_atp` during `FulfillmentService::allocate()`.
- **Exception**: `Obelaw\Ium\Sales\Exceptions\InsufficientInventoryException`
- **Why It Matters**: Prevents overselling and prevents releasing unachievable pick instructions to warehouse operators.
- **Recovery Path**: Check ATP stock prior to hard allocation, route line to another sourcing node, or wait for upstream inventory replenishment.

---

## 5. Invariant 4: Split & Cancellation Governance

### The Law
A confirmed order that has been released for picking/packing (`Released`, `PartiallyShipped`, `Completed`) cannot be cancelled in place.

- **Condition**: Invoking `OrderService::cancel()` when `$order->status->isCancellablePreRelease()` is `false`.
- **Exception**: `Obelaw\Ium\Sales\Exceptions\CannotCancelReleasedOrderException`
- **Why It Matters**: Active warehouse pick lists, packed parcels, and carrier manifests cannot be silently invalidated in database tables without physical recall and inventory restock.
- **Recovery Path**: Intercept the physical fulfillment batch in WMS, process warehouse goods return, and initiate an RMA return or compensating credit note.

---

## 6. Invariant 5: RMA Quantity Integrity

### The Law
$$\text{Requested Return Qty} \le \text{Shipped Qty} - \text{Previously Returned Qty}$$

- **Condition**: Requesting an RMA for items or quantities that have not been shipped, or that have already been returned and refunded.
- **Exception**: `Obelaw\Ium\Sales\Exceptions\InvalidRmaQuantityException`
- **Why It Matters**: Prevents return fraud and duplicate credit note issuance.
- **Recovery Path**: Query `$orderLine->returnableQuantity()` prior to submitting an RMA request.
