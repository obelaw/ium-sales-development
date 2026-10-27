# Testing & Verification Guide

This guide details the test structure, Orchestra Testbench setup, PestPHP assertions, and verification commands for the Sales & OMS domain module.

---

## 1. Running Tests

Execute PestPHP from the root of [`obelaw/ium-sales`](https://github.com/obelaw/ium-sales):

```bash
# Run the entire test suite
./vendor/bin/pest

# Run a specific feature test
./vendor/bin/pest tests/Feature/PriceLockInvariantTest.php

# Run with verbose output
./vendor/bin/pest -v
```

---

## 2. Test Environment Setup (`tests/TestCase.php`)

```php
namespace Obelaw\Ium\Sales\Tests;

use Obelaw\Ium\Providers\ObelawiumServiceProvider;
use Obelaw\Ium\Sales\Providers\ObelawSalesServiceProvider;
use Orchestra\Testbench\TestCase as Orchestra;

abstract class TestCase extends Orchestra
{
    protected function getPackageProviders($app): array
    {
        return [
            ObelawiumServiceProvider::class,
            ObelawSalesServiceProvider::class,
        ];
    }

    protected function defineEnvironment($app): void
    {
        $app['config']->set('database.default', 'testing');
        $app['config']->set('database.connections.testing', [
            'driver'   => 'sqlite',
            'database' => ':memory:',
            'prefix'   => '',
        ]);
        $app['config']->set('ium.sales.price_lock_strict', true);
        $app['config']->set('ium.sales.audit_enabled', true);
    }

    protected function setUp(): void
    {
        parent::setUp();
        $this->artisan('migrate')->run();
    }
}
```

---

## 3. Essential Test Assertions

### Verifying Gateway Resolution & Physical Table Prefix:

```php
it('verifies domain resolution and physical table naming', function () {
    expect(ium()->hasDomain('sales'))->toBeTrue();
    expect(ium()->sales())->toBeInstanceOf(\Obelaw\Ium\Sales\SalesDomain::class);

    $order = new \Obelaw\Ium\Sales\Models\SalesOrder();
    expect($order->getTable())->toBe('ium_sales_orders');
});
```

### Verifying Domain Event Dispatches:

```php
use Illuminate\Support\Facades\Event;
use Obelaw\Ium\Sales\Events\SalesOrderConfirmed;

it('dispatches SalesOrderConfirmed when order is confirmed', function () {
    Event::fake([SalesOrderConfirmed::class]);

    $order = ium()->sales()->orders()->create($dto);
    ium()->sales()->orders()->confirm($order);

    Event::assertDispatched(SalesOrderConfirmed::class);
});
```

### Verifying The Price-Lock Law:

```php
it('prevents price mutations on confirmed orders', function () {
    $order = ium()->sales()->orders()->create($dto);
    $order = ium()->sales()->orders()->confirm($order);

    expect(fn() => $order->update(['grand_total' => 10.0]))
        ->toThrow(\Obelaw\Ium\Sales\Exceptions\OrderPriceLockedException::class);
});
```
