# Practical Sales & OMS Code Recipes

This document provides ready-to-use PHP code recipes for executing common commercial workflows in `obelaw/ium-sales`.

---

## Recipe 1: Commercial Quotation Workflow

```php
use Obelaw\Ium\Sales\Data\CreateQuotationDto;
use Obelaw\Ium\Sales\Data\QuotationLineDto;

// 1. Create a priced commercial proposal
$quotation = ium()->sales()->quotations()->create(new CreateQuotationDto(
    lines: [
        new QuotationLineDto(
            sku: 'SRV-ENTERPRISE-01',
            name: 'Dedicated Cloud Blade',
            unitPrice: 1500.0,
            quantity: 2.0,
            discountAmount: 150.0,
            taxRate: 14.0,
        ),
    ],
    customerType: 'organization',
    customerId: 88,
    channelCode: 'b2b-portal',
    currency: 'USD',
    shippingTotal: 75.0,
    notes: 'Valid for 30 calendar days.',
));

// 2. Transmit quotation to customer
$quotation = ium()->sales()->quotations()->send($quotation);

// 3. Customer acceptance
$quotation = ium()->sales()->quotations()->accept($quotation);

// 4. Convert accepted proposal into a binding Sales Order
$order = ium()->sales()->quotations()->convertToOrder($quotation);
```

---

## Recipe 2: Omnichannel Order Ingestion (Idempotent)

```php
use Obelaw\Ium\Sales\Data\IngestOrderDto;
use Obelaw\Ium\Sales\Data\SalesOrderLineDto;

$ingestDto = new IngestOrderDto(
    channelCode: 'ecommerce-shopify',
    channelOrderId: 'SP-998811',
    customerEmail: 'customer@example.com',
    customerName: 'Jordan Doe',
    lines: [
        new SalesOrderLineDto(
            sku: 'TSHIRT-BLK-L',
            name: 'Black Crewneck Shirt (L)',
            unitPrice: 28.0,
            quantity: 3.0,
            taxRate: 8.5,
        ),
    ],
    shippingTotal: 7.99,
);

// Idempotent ingestion: calling multiple times with the same channelOrderId returns the existing order
$order = ium()->sales()->orders()->ingest($ingestDto);
```

---

## Recipe 3: Multi-Facility Split Shipment & Sourcing Node Routing

```php
use Obelaw\Ium\Sales\Data\MarkShippedDto;
use Obelaw\Ium\Sales\Data\SplitBatchDto;
use Obelaw\Ium\Sales\Data\SplitOrderDto;

// 1. Confirm order (Locks prices)
$order = ium()->sales()->orders()->confirm($order);

// 2. Allocate ATP stock across facilities
$order = ium()->sales()->fulfillment()->allocate($order, 'WH-CENTRAL');

// 3. Split order into two discrete fulfillment shipments
$line1 = $order->lines()->first();
$line2 = $order->lines()->skip(1)->first();

$batches = ium()->sales()->fulfillment()->split($order, new SplitOrderDto(batches: [
    new SplitBatchDto(
        sourcingNodeId: 'WH-CENTRAL',
        items: [['order_line_id' => $line1->id, 'quantity' => (float) $line1->quantity]],
        carrierCode: 'UPS',
        serviceLevel: 'GROUND',
    ),
    new SplitBatchDto(
        sourcingNodeId: 'STORE-WEST',
        items: [['order_line_id' => $line2->id, 'quantity' => (float) $line2->quantity]],
        carrierCode: 'FEDEX',
        serviceLevel: 'EXPRESS',
    ),
]));

// 4. Release individual batch to WMS
$firstBatch = $batches->first();
$firstBatch = ium()->sales()->fulfillment()->releaseBatch($firstBatch);

// 5. Update carrier tracking upon dispatch
$firstBatch = ium()->sales()->fulfillment()->markBatchShipped($firstBatch, new MarkShippedDto(
    carrierCode: 'UPS',
    trackingNumber: '1Z9999999999999999',
));
```

---

## Recipe 4: Reverse Logistics & RMA Restock Disposition

```php
use Obelaw\Ium\Sales\Data\CreateRmaDto;
use Obelaw\Ium\Sales\Data\ReceiveRmaGoodsDto;
use Obelaw\Ium\Sales\Data\RmaLineDto;
use Obelaw\Ium\Sales\Enums\RmaDisposition;

// 1. Customer initiates return request for delivered goods
$line = $order->lines()->first();

$rma = ium()->sales()->rmas()->request(new CreateRmaDto(
    salesOrderId: $order->id,
    reasonCode: 'DEFECTIVE_PRODUCT',
    reasonDescription: 'Device does not power on out of the box.',
    lines: [
        new RmaLineDto(salesOrderLineId: $line->id, quantityRequested: 1.0),
    ],
));

// 2. Authorize RMA
$rma = ium()->sales()->rmas()->authorize($rma);

// 3. Warehouse receives parcel and conducts technical inspection
$rmaLine = $rma->lines()->first();
$rma = ium()->sales()->rmas()->receiveGoods($rma, new ReceiveRmaGoodsDto(
    items: [
        [
            'rma_line_id' => $rmaLine->id,
            'quantity_received' => 1.0,
            'disposition' => RmaDisposition::Restock->value, // or Scrap / Repair
        ],
    ]
));

// 4. Approve credit note compensation
$rma = ium()->sales()->rmas()->approveCredit($rma);

// 5. Close RMA case
$rma = ium()->sales()->rmas()->close($rma);
```
