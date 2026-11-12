<?php

namespace App\Http\Controllers;

use App\Models\Pedido;
use App\Support\CobroQr;
use Illuminate\Contracts\View\View;
use Illuminate\Validation\ValidationException;

/**
 * Pasarela de pago de PRUEBA: la página que abre el QR del pedido.
 * GET muestra qué se paga; POST (botón "Pagar") procesa el cobro como lo haría
 * un banco. No se cobra dinero real. La referencia del QR es imposible de
 * adivinar, por eso no pide sesión (quien escanea puede ser otro celular).
 */
class PagoQrController extends Controller
{
    public function ver(string $referencia): View
    {
        $pedido = $this->pedido($referencia);

        return view('pago-qr', ['pedido' => $pedido, 'resultado' => null]);
    }

    public function pagar(string $referencia): View
    {
        $pedido = $this->pedido($referencia);
        try {
            $pedido = CobroQr::procesar($pedido);
            $resultado = 'pagado';
        } catch (ValidationException $e) {
            $resultado = $e->validator->errors()->first();
        }

        return view('pago-qr', ['pedido' => $pedido, 'resultado' => $resultado]);
    }

    private function pedido(string $referencia): Pedido
    {
        abort_unless(CobroQr::referenciaValida($referencia), 404);

        return Pedido::with('negocio')
            ->where('metodo_pago', 'qr')
            ->where('referencia_pago', $referencia)
            ->firstOrFail();
    }
}
