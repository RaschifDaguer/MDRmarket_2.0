{{-- Pasarela de pago de PRUEBA (ver PagoQrController y App\Support\CobroQr). --}}
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex">
    <title>Pago con QR · MDR Market</title>
    <style>
        :root { --verde: #1b8a5a; --texto: #1d2321; --suave: #5b6663; --fondo: #f3f6f5; --tarjeta: #fff; --borde: #dfe6e3; }
        @media (prefers-color-scheme: dark) {
            :root { --texto: #e8eeeb; --suave: #a3b0ac; --fondo: #121615; --tarjeta: #1c2220; --borde: #2c3532; }
        }
        * { box-sizing: border-box; }
        body { margin: 0; min-height: 100vh; display: grid; place-items: center; padding: 16px;
               font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; background: var(--fondo); color: var(--texto); }
        main { width: 100%; max-width: 380px; background: var(--tarjeta); border: 1px solid var(--borde); border-radius: 16px; padding: 24px; text-align: center; }
        .marca { font-weight: 700; color: var(--verde); letter-spacing: .02em; }
        .aviso { margin: 12px 0 20px; padding: 8px 12px; border-radius: 8px; font-size: 13px; background: #fff4d6; color: #6b4e00; }
        .monto { font-size: 40px; font-weight: 700; margin: 4px 0; }
        .detalle { color: var(--suave); margin: 0 0 24px; }
        button { width: 100%; padding: 14px; border: 0; border-radius: 12px; font-size: 17px; font-weight: 600; color: #fff; background: var(--verde); cursor: pointer; }
        .ok { font-size: 56px; line-height: 1; color: var(--verde); }
        .error { color: #b3261e; }
    </style>
</head>
<body>
<main>
    <div class="marca">MDR Market · Pago con QR</div>
    <div class="aviso">Pago de prueba: no se cobra dinero real.</div>

    @if ($resultado === 'pagado' || ($resultado === null && $pedido->estado_pago === 'pagado'))
        <div class="ok" aria-hidden="true">✓</div>
        <h1>Cobro realizado</h1>
        <p class="detalle">Bs {{ number_format((float) $pedido->total, 2) }} · Pedido #{{ $pedido->id }} · {{ $pedido->negocio->nombre }}</p>
        <p>Ya puedes volver a la app: tu pedido sigue su curso.</p>
    @elseif ($resultado !== null)
        <h1 class="error">No se pudo cobrar</h1>
        <p class="detalle">{{ $resultado }}</p>
    @elseif (in_array($pedido->estado, ['cancelado', 'rechazado'], true))
        <h1 class="error">Pedido cancelado</h1>
        <p class="detalle">Este pedido ya no se puede pagar.</p>
    @else
        <p class="detalle">Pagar a <strong>{{ $pedido->negocio->nombre }}</strong> · Pedido #{{ $pedido->id }}</p>
        <div class="monto">Bs {{ number_format((float) $pedido->total, 2) }}</div>
        <form method="post" action="{{ url('/pago-qr/'.$pedido->referencia_pago) }}" style="margin-top: 24px">
            @csrf
            <button type="submit">Pagar Bs {{ number_format((float) $pedido->total, 2) }}</button>
        </form>
    @endif
</main>
</body>
</html>
