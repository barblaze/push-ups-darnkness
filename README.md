# PushQuest

Push-ups como un juego: la app usa la cámara y detección de pose en tiempo real
(Google ML Kit, 100% en el dispositivo) para contar tus push-ups y evaluar tu
forma, con puntos, rachas, niveles, avatar, misión diaria, logros y estadísticas.

- Modos: piso, paralelas (umbrales distintos por profundidad de bajada) y
  libre (solo cuenta tus reps, sin reglas ni puntuación).
- Feedback en vivo: profundidad, cadera baja/elevada, plancha, no visibilidad.
- Reps "perfectas" dan más puntos y mantienen el combo; una mala lo rompe.
- Objetivo diario determinista (6-24 reps) con bonus de +50 XP.
- Vista frontal: la cámara te ve de frente y el conteo se normaliza con el
  recorrido real de tu cabeza y cuerpo (se auto-calibra en la cuenta atrás),
  sin calibración manual.
- Forma evaluada en vivo: profundidad de bajada y cadera baja/elevada respecto
  a la línea hombros→tobillos (sag/pike/plancha).
- Sin servidores: todos los datos viven en el dispositivo.

## Estructura

```
packages/pushquest_logic/   Lógica pura (Dart), tests locales con el SDK de Dart
lib/                        App Flutter (pantallas, pose, estado, tema)
android/                    Configuración Android (Gradle 8.14, AGP 8.11.1)
.github/workflows/build.yml Pipeline de build del APK
```

## Compilar el APK (GitHub Actions)

No necesitas toolchain local de Flutter/Android:

1. Crea un repositorio en GitHub y súbelo:

   ```bash
   git remote add origin https://github.com/TU_USUARIO/pushquest.git
   git push -u origin main
   ```

2. Abre la pestaña **Actions** en GitHub: el workflow `Build` compila, corre los
   tests y genera el APK.

3. Cuando termine, entra al run y baja el artefacto **pushquest-apk**.

4. Instala el APK en tu móvil Android (Samsung Galaxy S23 Ultra con ARM64
   funciona perfecto): tócalo y confirma la instalación. Habilita "Instalar
   apps desconocidas" para tu gestor de archivos si te lo pide.

## Uso

1. Abre PushQuest y dale permiso de cámara.
2. Elige modo **Piso**, **Paralelas** o **Libre**.
3. Colócate de frente al celular (vertical, con los pies dentro del cuadro) y
   toca **ENTRENAR**: la cuenta atrás calibra el rango de tu cabeza y luego la
   app cuenta tus push-ups, evalúa tu forma y acumula puntos.

## Desarrollo local

La lógica se valida con el SDK de Dart (sin Flutter):

```bash
cd packages/pushquest_logic
dart pub get
dart analyze
dart test
```

Todo lo demás (análisis, tests y build de la app) lo corre el CI.
