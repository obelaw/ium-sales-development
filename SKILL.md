---
name: ium-sales-development
description: >-
  Comprehensive guide and workflow for AI agents developing with, integrating against, or extending
  the Obelawium Sales & Order Management System (ium-sales / OMS) domain module. Covers the ium()->sales()
  fluent DSL, commercial quotations, omnichannel order ingestion, price-lock freeze invariants,
  Available-To-Promise (ATP) stock allocation, multi-facility split fulfillment batches, Return Merchandise
  Authorizations (RMA), and Anti-Corruption Layer (ACL) cross-domain translations.
tags: [obelaw, ium, sales, oms, order-management, split-fulfillment, rma, price-lock, omnichannel, pest, ddd]
---

# Obelawium Sales & Order Management (`ium-sales`) Development Guide

This skill guides an AI agent through developing with, integrating against, and extending the **Obelawium Sales & Order Management System (Sales / OMS)** domain module (`obelaw/ium-sales`).

---

## 1. Domain Philosophy & Fluent Architecture

The Sales / OMS package serves as the commercial execution engine in the Obelawium ERP ecosystem. It is strictly **headless and decoupled from presentation** (no HTTP controllers, routes, Blade, Livewire, or Inertia).

All external domain interactions must flow through the central Obelawium fluent DSL:

```php
ium()->sales()->[service]()->[method]()
```

### Complete Service Catalog (8 Core Services)

| Service Accessor | Service Class | Primary Responsibilities |
| :--- | :--- | :--- |
| `ium()->sales()->orders()` | [`OrderService`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Services/OrderService.php) | Master sales order creation, omnichannel ingestion, confirmation, price-lock freezing, and cancellation governance. |
| `ium()->sales()->quotations()` | [`QuotationService`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Services/QuotationService.php) | Commercial quotation/proforma drafting, sending, customer acceptance, rejection, expiration, and conversion into orders. |
| `ium()->sales()->fulfillment()` | [`FulfillmentService`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Services/FulfillmentService.php) | Sourcing node ATP allocation, multi-facility split shipment routing, WMS batch releases, and carrier shipping/delivery tracking. |
| `ium()->sales()->rmas()` | [`RmaService`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Services/RmaService.php) | Reverse logistics, Return Merchandise Authorizations (RMA), goods inspection disposition (`restock`, `scrap`, `repair`), and credit approvals. |
| `ium()->sales()->channels()` | [`ChannelService`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Services/ChannelService.php) | Omnichannel profile management (`ecommerce`, `mobile`, `b2b`, `pos`, `marketplace`). |
| `ium()->sales()->pricing()` | [`PricingEngineService`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Services/PricingEngineService.php) | Line-level discount, tax rate, and financial balance equation verification. |
| `ium()->sales()->audit()` | [`AuditService`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Services/AuditService.php) | Append-only immutable forensic commercial audit logging for all mutations and state transitions. |
| `ium()->sales()->acl()` | [`AclService`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Services/AclService.php) | Anti-Corruption Layer translating inbound channel payloads (Carts, POS, EDI) and outbound contracts (WMS, TMS, FMS). |

---

## 2. Non-Negotiable Domain Invariants ("The Law")

When developing or executing commercial actions in the Sales domain, you **MUST NEVER violate** these 5 core invariants:

1. **Order Financial Balance Rule**:
   $$\text{Total Order Value} = \sum(\text{Line Prices} - \text{Discounts}) + \text{Taxes} + \text{Shipping Fees}$$
   Every quotation and order must balance perfectly. Line-level amounts after discounts plus taxes and shipping must match `grand_total`. Violations during confirmation abort immediately with [`InvalidFinancialBalanceException`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Exceptions/InvalidFinancialBalanceException.php).

2. **The Price-Lock Law (Pricing Immutability)**:
   Once a `SalesOrder` transitions to `Confirmed`, its unit prices, discounts, taxes, shipping fees, currency, and line items are **permanently frozen**. Direct in-place updates or deletions throw [`OrderPriceLockedException`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Exceptions/OrderPriceLockedException.php). Corrections require formal compensating documents (Supplementary Orders, Credit Notes, or RMAs).

3. **Stock Allocation Rule**:
   Hard allocation cannot occur without verified Available-To-Promise (ATP) stock in the target fulfillment node. If requested quantity exceeds available ATP, the transaction aborts with [`InsufficientInventoryException`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Exceptions/InsufficientInventoryException.php).

4. **Split & Cancellation Governance**:
   Confirmed orders that have entered active warehouse fulfillment (`Released`, `Shipped`) **cannot be cancelled in place**. Attempting in-place cancellation throws [`CannotCancelReleasedOrderException`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Exceptions/CannotCancelReleasedOrderException.php). Cancellations post-release must follow goods interception and formal RMA/credit compensation. Pre-release cancellation is allowed.

5. **RMA Quantity Integrity**:
   Returned quantities on an RMA cannot exceed eligible returnable quantities:
   $$\text{Max Returnable} = \text{Shipped Quantity} - \text{Previously Returned Quantity}$$
   Violations throw [`InvalidRmaQuantityException`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Exceptions/InvalidRmaQuantityException.php).

---

## 3. Agent Decision Matrix

| Task / Scenario | Method to Invoke | Input DTO / Parameters | Expected Output |
| :--- | :--- | :--- | :--- |
| **Draft a Commercial Quotation** | `ium()->sales()->quotations()->create($dto)` | [`CreateQuotationDto`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Data/CreateQuotationDto.php) | [`Quotation`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Models/Quotation.php) (`draft`) |
| **Send Quotation to Customer** | `ium()->sales()->quotations()->send($quote)` | `Quotation` instance | `Quotation` (`sent`) |
| **Accept Quotation** | `ium()->sales()->quotations()->accept($quote)` | `Quotation` instance | `Quotation` (`accepted`), emits `QuotationAccepted` |
| **Convert Quotation to Order** | `ium()->sales()->quotations()->convertToOrder($quote)` | `Quotation` instance | [`SalesOrder`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Models/SalesOrder.php) (`draft`), quote marked `converted` |
| **Create a Sales Order** | `ium()->sales()->orders()->create($dto)` | [`CreateSalesOrderDto`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Data/CreateSalesOrderDto.php) | `SalesOrder` (`draft`) |
| **Ingest Omnichannel Order** | `ium()->sales()->orders()->ingest($dto)` | [`IngestOrderDto`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Data/IngestOrderDto.php) | `SalesOrder` (idempotent by `channel_order_id`) |
| **Confirm Order (Price Lock)** | `ium()->sales()->orders()->confirm($order)` | `SalesOrder` instance | `SalesOrder` (`confirmed`), emits `SalesOrderConfirmed` |
| **Cancel Pre-Release Order** | `ium()->sales()->orders()->cancel($order, $reason)` | `SalesOrder` instance, reason string | `SalesOrder` (`cancelled`), emits `OrderCancelled` |
| **Allocate Stock (ATP Check)** | `ium()->sales()->fulfillment()->allocate($order, $node, $atp)` | `SalesOrder`, node ID, optional ATP map | `SalesOrder` (`allocated`), creates default batch |
| **Split Order Across Nodes** | `ium()->sales()->fulfillment()->split($order, $dto)` | `SalesOrder`, [`SplitOrderDto`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Data/SplitOrderDto.php) | `Collection<FulfillmentBatch>`, emits `OrderSplitted` |
| **Release Batch to WMS** | `ium()->sales()->fulfillment()->releaseBatch($batch)` | [`FulfillmentBatch`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Models/FulfillmentBatch.php) | `FulfillmentBatch` (`released`), emits `FulfillmentBatchReleased` |
| **Mark Batch Shipped** | `ium()->sales()->fulfillment()->markBatchShipped($batch, $dto)` | `FulfillmentBatch`, [`MarkShippedDto`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Data/MarkShippedDto.php) | `FulfillmentBatch` (`shipped`), updates line shipped quantities |
| **Mark Batch Delivered** | `ium()->sales()->fulfillment()->markBatchDelivered($batch)` | `FulfillmentBatch` instance | `FulfillmentBatch` (`delivered`), auto-completes order if final |
| **Request RMA Return** | `ium()->sales()->rmas()->request($dto)` | [`CreateRmaDto`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Data/CreateRmaDto.php) | [`ReturnMerchandiseAuthorization`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Models/ReturnMerchandiseAuthorization.php) (`pending_authorization`) |
| **Authorize RMA** | `ium()->sales()->rmas()->authorize($rma)` | `ReturnMerchandiseAuthorization` | RMA (`authorized`), emits `ReturnAuthorized` |
| **Receive & Inspect RMA Goods** | `ium()->sales()->rmas()->receiveGoods($rma, $dto)` | RMA, [`ReceiveRmaGoodsDto`](file:///E:/projects/obelaw/modules/sales/ium-sales/src/Data/ReceiveRmaGoodsDto.php) | RMA (`received`), updates disposition (`restock`/`scrap`) |
| **Approve RMA Credit** | `ium()->sales()->rmas()->approveCredit($rma)` | `ReturnMerchandiseAuthorization` | RMA (`approved_for_credit`), updates line returned quantities |
| **Export Outbound WMS Payload** | `ium()->sales()->acl()->exportToWmsPayload($batch)` | `FulfillmentBatch` instance | Pick/pack instruction array for WMS |
| **Export Outbound TMS Payload** | `ium()->sales()->acl()->exportToTmsPayload($batch)` | `FulfillmentBatch` instance | Dispatch/waybill array for TMS |
| **Export Outbound FMS Payload** | `ium()->sales()->acl()->exportToFmsPayload($order)` | `SalesOrder` instance | Commercial customer invoice array for Accounting |

---

## 4. Key Workflows & Code Patterns

### Pattern 1: Complete Omnichannel Commercial Order Flow

```php
use Obelaw\Ium\Sales\Data\CreateSalesOrderDto;
use Obelaw\Ium\Sales\Data\SalesOrderLineDto;

// 1. Create Order
$order = ium()->sales()->orders()->create(new CreateSalesOrderDto(
    lines: [
        new SalesOrderLineDto(sku: 'PROD-100', name: 'Premium Monitor', unitPrice: 300.0, quantity: 2.0),
    ],
    customerType: 'customer',
    customerId: 45,
    channelCode: 'd2c-storefront',
    currency: 'USD',
    shippingTotal: 15.0,
));

// 2. Confirm (Validates balance & locks prices permanently)
$order = ium()->sales()->orders()->confirm($order);

// 3. Allocate verified inventory
$order = ium()->sales()->fulfillment()->allocate($order, 'WH-MAIN', ['PROD-100' => 50.0]);

// 4. Release batch to WMS for picking & packing
$batch = $order->batches()->first();
ium()->sales()->fulfillment()->releaseBatch($batch);
```

### Pattern 2: Multi-Facility Split Shipment

```php
use Obelaw\Ium\Sales\Data\SplitBatchDto;
use Obelaw\Ium\Sales\Data\SplitOrderDto;

// Split an order between a regional warehouse and a retail store
$lineA = $order->lines()->where('sku', 'ITEM-HEAVY')->first();
$lineB = $order->lines()->where('sku', 'ITEM-LIGHT')->first();

$batches = ium()->sales()->fulfillment()->split($order, new SplitOrderDto(batches: [
    new SplitBatchDto(
        sourcingNodeId: 'WH-REGIONAL',
        items: [['order_line_id' => $lineA->id, 'quantity' => 1.0]],
        carrierCode: 'FREIGHT-X',
    ),
    new SplitBatchDto(
        sourcingNodeId: 'STORE-DOWNTOWN',
        items: [['order_line_id' => $lineB->id, 'quantity' => 2.0]],
        carrierCode: 'COURIER-SAME-DAY',
    ),
]));
```

### Pattern 3: RMA Return & Restock Disposition Flow

```php
use Obelaw\Ium\Sales\Data\CreateRmaDto;
use Obelaw\Ium\Sales\Data\ReceiveRmaGoodsDto;
use Obelaw\Ium\Sales\Data\RmaLineDto;
use Obelaw\Ium\Sales\Enums\RmaDisposition;

// 1. Customer requests return of 1 unit
$rma = ium()->sales()->rmas()->request(new CreateRmaDto(
    salesOrderId: $order->id,
    reasonCode: 'WRONG_COLOR',
    lines: [
        new RmaLineDto(salesOrderLineId: $lineB->id, quantityRequested: 1.0),
    ],
));

// 2. Customer support authorizes the return
$rma = ium()->sales()->rmas()->authorize($rma);

// 3. Warehouse receives parcel, inspects, and approves restock
$rmaLine = $rma->lines()->first();
$rma = ium()->sales()->rmas()->receiveGoods($rma, new ReceiveRmaGoodsDto(
    items: [
        [
            'rma_line_id' => $rmaLine->id,
            'quantity_received' => 1.0,
            'disposition' => RmaDisposition::Restock->value,
        ],
    ]
));

// 4. Approve credit note compensation (updates original order line return counts)
$rma = ium()->sales()->rmas()->approveCredit($rma);
```

---

## 5. Reference Documentation & Playbooks

- [**Architecture & State Machines Reference**](./references/architecture.md) — Detailed bounded context boundaries, entity topology, quotation/order/RMA state machines, and lifecycle transitions.
- [**Invariants & Exceptions Playbook**](./references/invariants-and-exceptions.md) — Complete rules of "The Law", exception classes, conditions, and remediation paths.
- [**Development Recipes**](./references/recipes.md) — Tested code recipes for every commercial OMS scenario.
- [**Cross-Domain Integration (ACL)**](./references/cross-domain-integration.md) — Anti-Corruption Layer contracts with WMS, TMS, Accounting (FMS), CRM, and Catalog.
- [**Testing & Verification Guide**](./references/testing-and-verification.md) — PestPHP test runner, event assertions, and test fixtures.
