<?php

namespace App\Support;

use App\Models\Configuracion;

/**
 * Términos y condiciones de MDR Market. Un solo texto para la app
 * (GET /api/terminos) y la página web (/terminos).
 *
 * Al cambiar el texto, sube VERSION: la app les pide a todos aceptarlos de
 * nuevo (usuario.terminos_version distinta = pendiente).
 */
class Terminos
{
    public const VERSION = '2026-11-18';

    public const ACTUALIZADO = '18 de noviembre de 2026';

    /** Lo que se acepta con la casilla al crear la cuenta. */
    public const DECLARACION = 'Declaro que soy mayor de 18 años y acepto los Términos y condiciones de MDR Market.';

    public static function datos(): array
    {
        return [
            'version' => self::VERSION,
            'actualizado' => self::ACTUALIZADO,
            'declaracion' => self::DECLARACION,
            'resumen' => 'MDR Market conecta a clientes con negocios y repartidores de Santa Cruz de la Sierra. '
                .'Para usarla tienes que ser mayor de 18 años. Las bebidas alcohólicas y el tabaco solo se venden a '
                .'mayores de edad y el repartidor te pedirá tu carnet al entregarlos.',
            'secciones' => self::secciones(),
        ];
    }

    /** @return list<array{titulo: string, parrafos: list<string>}> */
    public static function secciones(): array
    {
        $comision = rtrim(rtrim(number_format((float) Configuracion::valor('comision_plataforma_pct', 0), 2, ',', ''), '0'), ',');

        return [
            [
                'titulo' => '1. Qué es MDR Market',
                'parrafos' => [
                    'MDR Market es una aplicación que conecta a personas que quieren comprar (clientes) con negocios '
                    .'de Santa Cruz de la Sierra (comerciantes) y con repartidores independientes que llevan los pedidos.',
                    'MDR Market no fabrica ni vende los productos: cada negocio es responsable de lo que publica y vende, '
                    .'y cada repartidor, de la entrega.',
                ],
            ],
            [
                'titulo' => '2. Quién puede usarla',
                'parrafos' => [
                    'Solo personas mayores de 18 años. Al crear tu cuenta declaras que eres mayor de edad y que tus datos '
                    .'(nombre, carnet de identidad, teléfono) son verdaderos y tuyos.',
                    'Cada persona tiene una sola cuenta. Eres responsable de cuidar tu contraseña y de lo que se haga con tu cuenta.',
                ],
            ],
            [
                'titulo' => '3. Qué puedes hacer en la aplicación',
                'parrafos' => [
                    'Como cliente: buscar productos de negocios verificados, hacer pedidos, pagar en efectivo al recibir o con QR, '
                    .'seguir tu pedido en el mapa, calificar y reportar problemas.',
                    'Como comerciante: registrar tu negocio, publicar productos, recibir pedidos y ver tus ventas, después de '
                    .'que revisemos tus documentos.',
                    'Como repartidor: recibir y entregar pedidos cerca de ti, después de que revisemos tus documentos y tu vehículo.',
                ],
            ],
            [
                'titulo' => '4. Qué nos permites hacer',
                'parrafos' => [
                    'Usar tus datos para procesar tus pedidos y mostrarle al negocio y al repartidor lo necesario para '
                    .'entregarlo: tu nombre, tu teléfono y la dirección de entrega.',
                    'Usar tu ubicación para calcular el envío y mostrar el recorrido. Si eres repartidor, mostrarle tu '
                    .'ubicación al cliente mientras llevas su pedido.',
                    'Revisar las fotos de tus documentos (carnet, licencias, permisos) para verificar tu identidad. Solo las '
                    .'ve el equipo de MDR Market.',
                    'Enviarte avisos sobre tus pedidos y tu cuenta.',
                    'Ocultar productos y suspender o bloquear cuentas que no cumplan estas reglas o que reciban reportes graves.',
                ],
            ],
            [
                'titulo' => '5. Bebidas alcohólicas y tabaco',
                'parrafos' => [
                    'VENTA PROHIBIDA A MENORES DE 18 AÑOS. La venta de bebidas alcohólicas y de tabaco a menores de edad '
                    .'está prohibida (Ley N° 259 de Control al Expendio y Consumo de Bebidas Alcohólicas y Ley N° 1280 de '
                    .'Prevención y Control al Consumo de los Productos de Tabaco).',
                    'Antes de comprarlos confirmas que eres mayor de 18 años y aceptas una declaración: que la información '
                    .'es verdadera, que la compra es tuya y para un adulto, y que respondes por ella. Si das información '
                    .'falsa sobre tu edad, la responsabilidad es tuya.',
                    'El repartidor te pedirá tu carnet de identidad al entregar. Si no lo muestras o eres menor de edad, '
                    .'no entregará el pedido.',
                    'Solo pueden vender bebidas alcohólicas los negocios con su Autorización de expendio de bebidas '
                    .'alcohólicas y su Licencia de funcionamiento municipal aprobadas por nuestro equipo. Los productos de '
                    .'tabaco o alcohol se publican solo en sus categorías para mayores de 18.',
                    'El consumo excesivo de alcohol y el consumo de tabaco son dañinos para la salud. Si bebes, no manejes.',
                ],
            ],
            [
                'titulo' => '6. Medicamentos',
                'parrafos' => [
                    'Solo las farmacias verificadas pueden vender medicamentos: con su Resolución de apertura del SEDES '
                    .'y su Licencia de funcionamiento municipal aprobadas por nuestro equipo.',
                    'En MDR Market solo se venden medicamentos de venta libre, que no necesitan receta médica. La farmacia '
                    .'lo confirma al publicar cada uno y responde por esa información.',
                ],
            ],
            [
                'titulo' => '7. Comerciantes',
                'parrafos' => [
                    'Publica solo productos legales, con fotos, precios y stock reales. Los documentos que subas deben ser '
                    .'verdaderos y estar vigentes.',
                    "Por cada venta entregada, MDR Market cobra una comisión del {$comision} % del valor de los productos.",
                    'Las licorerías y farmacias deben mantener sus permisos vigentes. Si vencen o son revocados, sus '
                    .'productos pueden salir del catálogo.',
                ],
            ],
            [
                'titulo' => '8. Repartidores',
                'parrafos' => [
                    'Trabajas de forma independiente. Debes tener tus documentos vigentes (carnet, licencia de conducir, '
                    .'RUAT y SOAT si tu vehículo los necesita) y respetar las normas de tránsito.',
                    'Entrega cada pedido solo con el PIN del cliente. En pedidos con bebidas alcohólicas, pide el carnet y no '
                    .'los entregues a menores de edad.',
                ],
            ],
            [
                'titulo' => '9. Pagos y cancelaciones',
                'parrafos' => [
                    'Puedes pagar en efectivo al recibir o con QR. MDR Market no guarda datos de tarjetas.',
                    'Puedes cancelar un pedido mientras el negocio no lo haya aceptado. Los pedidos que nadie acepta o que no '
                    .'se pagan a tiempo se cancelan solos.',
                ],
            ],
            [
                'titulo' => '10. Lo que no está permitido',
                'parrafos' => [
                    'Vender o pedir productos ilegales, falsificados o peligrosos; publicar medicamentos que necesitan receta; '
                    .'esconder tabaco o alcohol en otras categorías; hacer pedidos falsos; hacerse pasar por otra '
                    .'persona; insultar o acosar; escribir reseñas falsas; o usar la aplicación para cualquier fin ilegal.',
                ],
            ],
            [
                'titulo' => '11. Responsabilidad',
                'parrafos' => [
                    'MDR Market une a clientes, negocios y repartidores. Cada negocio responde por la calidad y legalidad de '
                    .'sus productos, y cada repartidor, por la entrega.',
                    'Hacemos lo posible para que la aplicación funcione siempre, pero puede tener interrupciones o errores.',
                ],
            ],
            [
                'titulo' => '12. Tus datos',
                'parrafos' => [
                    'Guardamos tus datos de forma segura y solo los usamos para lo que explican estos términos. No los '
                    .'vendemos. Puedes pedir que eliminemos tu cuenta.',
                ],
            ],
            [
                'titulo' => '13. Cambios y ley aplicable',
                'parrafos' => [
                    'Podemos actualizar estos términos. Si cambian, la aplicación te pedirá aceptarlos de nuevo.',
                    'Se rigen por las leyes del Estado Plurinacional de Bolivia.',
                ],
            ],
        ];
    }
}
