<?php

namespace App\Filament\Auth;

use Filament\Auth\MultiFactor\App\AppAuthentication;
use SensitiveParameter;

/**
 * Verificación en dos pasos del panel (Google Authenticator).
 *
 * Corrige el QR que no se veía: google2fa-qrcode v4 ya entrega la imagen como
 * "data:image/svg+xml;base64,…" y Filament la vuelve a envolver igual, así que
 * el navegador recibía una imagen rota. Aquí se quita la envoltura de más.
 */
class AutenticadorApp extends AppAuthentication
{
    public function generateQrCodeDataUri(#[SensitiveParameter] string $secret): string
    {
        $qr = parent::generateQrCodeDataUri($secret);
        $prefijo = 'data:image/svg+xml;base64,';

        if (str_starts_with($qr, $prefijo)) {
            $interior = base64_decode(substr($qr, strlen($prefijo)), true);
            if ($interior !== false && str_starts_with($interior, 'data:')) {
                return $interior;
            }
        }

        return $qr;
    }
}
