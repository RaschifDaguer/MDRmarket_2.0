{{-- Términos y condiciones (el mismo texto que muestra la app; ver App\Support\Terminos). --}}
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Términos y condiciones · MDR Market</title>
    <style>
        :root { --verde: #1b8a5a; --texto: #1d2321; --suave: #5b6663; --fondo: #f3f6f5; --tarjeta: #fff; --borde: #dfe6e3;
                --aviso-fondo: #fff4d6; --aviso-texto: #6b4e00; }
        @media (prefers-color-scheme: dark) {
            :root { --texto: #e8eeeb; --suave: #a3b0ac; --fondo: #121615; --tarjeta: #1c2220; --borde: #2c3532;
                    --aviso-fondo: #3a3018; --aviso-texto: #f3dc9b; }
        }
        * { box-sizing: border-box; }
        body { margin: 0; padding: 24px 16px 48px; background: var(--fondo); color: var(--texto); line-height: 1.6;
               font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
        main { max-width: 760px; margin: 0 auto; background: var(--tarjeta); border: 1px solid var(--borde);
               border-radius: 16px; padding: 28px 24px; }
        .marca { font-weight: 700; color: var(--verde); letter-spacing: .02em; }
        h1 { font-size: 28px; line-height: 1.25; margin: 4px 0 4px; }
        .fecha { color: var(--suave); margin: 0 0 20px; font-size: 14px; }
        .resumen { padding: 12px 16px; border-radius: 10px; background: var(--aviso-fondo); color: var(--aviso-texto); }
        h2 { font-size: 18px; margin: 28px 0 6px; }
        p { margin: 0 0 10px; }
    </style>
</head>
<body>
<main>
    <div class="marca">MDR Market</div>
    <h1>Términos y condiciones</h1>
    <p class="fecha">Actualizados el {{ $terminos['actualizado'] }} · versión {{ $terminos['version'] }}</p>
    <p class="resumen">{{ $terminos['resumen'] }}</p>

    @foreach ($terminos['secciones'] as $seccion)
        <h2>{{ $seccion['titulo'] }}</h2>
        @foreach ($seccion['parrafos'] as $parrafo)
            <p>{{ $parrafo }}</p>
        @endforeach
    @endforeach
</main>
</body>
</html>
