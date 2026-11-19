<?php

namespace App\Support;

use App\Models\Categoria;
use App\Models\Producto;
use Illuminate\Validation\ValidationException;

/**
 * Productos que necesitan cuidado legal al publicarlos:
 *
 * - Tabaco y bebidas alcohólicas (solo mayores de 18, Leyes 1280 y 259): si
 *   el nombre o la descripción lo parecen («cigarrillo», «vape», «cerveza»,
 *   «singani»…), tienen que ir en su categoría +18. Así nadie los esconde en
 *   otra categoría para saltarse el aviso de edad o el permiso de licorería.
 * - Medicamentos: solo de venta libre. La farmacia confirma que no necesitan
 *   receta médica al publicarlos (queda la fecha en venta_libre_confirmada_en).
 */
class ProductosRestringidos
{
    /** Palabras de productos para fumar (cigarrillos, vapeadores, narguile…). */
    private const TABACO = '(cigarr(?:illo|illos|o|os)|tabacos?|habanos?|vapes?|vapers?|vapeador(?:es)?|nicotina'
        .'|narguil[eéa]s?|hookahs?|shishas?|cachimbas?|puchos?|marlboro|lucky\s+strike|pall\s+mall)';

    /** Palabras de bebidas alcohólicas. ("alcohol" solo no: alcohol en gel, alcohol de farmacia.) */
    private const ALCOHOL = '(cervezas?|vinos?|singanis?|whiske?ys?|rones?|vodkas?|tequilas?|licor(?:es)?|fernet|ginebras?|gin'
        .'|piscos?|champa[gñ]nes?|champ[aá]n|espumantes?|sidras?|aguardientes?|vermut|vermouth|co[ñn]ac|cognac|brandy'
        .'|mezcal|sake|bebidas?\s+alcoh[oó]licas?)';

    /** Si dice esto, no es una bebida alcohólica aunque nombre una (cerveza sin alcohol, vinagre de vino). */
    private const SIN_ALCOHOL = '(sin\s+alcohol|cero\s+alcohol|0[.,]0\s*%?|vinagre)';

    /**
     * ¿El texto parece tabaco o una bebida alcohólica?
     *
     * @return array{tipo: 'tabaco'|'alcohol', palabra: string}|null
     */
    public static function detectar(string $texto): ?array
    {
        if (preg_match(self::patron(self::TABACO), $texto, $m)) {
            return ['tipo' => 'tabaco', 'palabra' => mb_strtolower($m[1])];
        }
        if (! preg_match(self::patron(self::SIN_ALCOHOL), $texto) && preg_match(self::patron(self::ALCOHOL), $texto, $m)) {
            return ['tipo' => 'alcohol', 'palabra' => mb_strtolower($m[1])];
        }

        return null;
    }

    /** Si parece tabaco o alcohol y no está en su categoría +18: 422 en "categoria_id". */
    public static function exigirCategoriaCorrecta(string $nombre, ?string $descripcion, int $categoriaId): void
    {
        $detectado = static::detectar($nombre.' '.$descripcion);
        if ($detectado === null) {
            return;
        }

        $categoria = Categoria::find($categoriaId);
        $correcta = $detectado['tipo'] === 'tabaco'
            ? in_array(Categoria::TABACO, [(int) $categoria?->id, (int) $categoria?->categoria_padre_id], true)
            : $categoria?->permiso === 'alcohol';

        if (! $correcta) {
            throw ValidationException::withMessages(['categoria_id' => $detectado['tipo'] === 'tabaco'
                ? "Parece un producto de tabaco («{$detectado['palabra']}»): publícalo en la categoría «Cigarrillos y tabaco» (solo mayores de 18)."
                    .' Si no lo es, cambia el nombre o la descripción para que no se confunda.'
                : "Parece una bebida alcohólica («{$detectado['palabra']}»): publícala en una categoría de «Bebidas alcohólicas» (solo mayores de 18)."
                    .' Si no lo es, cambia el nombre o la descripción para que no se confunda.']);
        }
    }

    /**
     * Medicamentos: la farmacia confirma que se venden sin receta. Hace falta
     * al publicarlo, al pasarlo a una categoría de medicamentos o si todavía
     * no lo confirmó. Devuelve true si hay que guardar la confirmación (ahora).
     */
    public static function confirmarVentaLibre(bool $confirmo, int $categoriaId, ?Producto $producto): bool
    {
        if (Categoria::whereKey($categoriaId)->value('permiso') !== 'farmacia') {
            return false;
        }
        if ($confirmo) {
            return true;
        }
        $hacefalta = $producto === null
            || (int) $producto->categoria_id !== $categoriaId
            || $producto->venta_libre_confirmada_en === null;
        if ($hacefalta) {
            throw ValidationException::withMessages(['confirma_venta_libre' => 'Confirma que este medicamento se vende sin receta médica:'
                .' en MDR Market no se publican medicamentos que necesitan receta.']);
        }

        return false;
    }

    /** Palabra completa, sin importar mayúsculas ni tildes de alrededor. */
    private static function patron(string $palabras): string
    {
        return '/(?<![\p{L}\p{N}])'.$palabras.'(?![\p{L}\p{N}])/iu';
    }
}
