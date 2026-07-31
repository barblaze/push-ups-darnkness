# PushQuest

Push-ups como un juego: la app usa la cámara y detección de pose en tiempo real
(MediaPipe, 100% en el dispositivo) para contar tus push-ups y evaluar tu forma,
con puntos, rachas, niveles, avatar, misión diaria, logros y estadísticas.

- Modos: piso y paralelas (umbrales distintos por profundidad de bajada).
- Feedback en vivo: profundidad, cadera baja/elevada, plancha, no visibilidad.
- Reps "perfectas" dan más puntos y mantienen el combo; una mala lo rompe.
- Objetivo diario determinista (10-48 reps) con bonus de +50 XP.
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
2. Elige modo **Piso** o **Paralelas**.
3. Coloca el teléfono de lado, con la cámara apuntando a tu perfil completo.
4. Toca **ENTRENAR** y haz push-ups: cuenta reps, evalúa tu forma y acumula
   puntos.

## Desarrollo local

La lógica se valida con el SDK de Dart (sin Flutter):

```bash
cd packages/pushquest_logic
dart pub get
dart analyze
dart test
```

Todo lo demás (análisis, tests y build de la app) lo corre el CI.
