# Turtle Flight — Character Asset Generation Prompt for Claude Code

## Project Context
Turtle Flight is a gyroscope-based iOS flight adventure game built with **Expo + React Native + Three.js**. The game features 6 animal characters that cannot fly, each with a unique flight vehicle. This prompt generates all character SVG assets needed for the game.

Bundle ID: `com.ggoboogihouse.turtleflight`
Target: All ages (4+ rating), young child as baseline for easiest control level.

---

## Global Design System Rules
All 6 characters MUST share these unified design rules to feel like they belong to the same game:

### Proportions
- **Head-to-body ratio**: 3:2 (head is larger than body)
- **Eye size**: 40% of head width
- **Style**: Chibi / super-deformed — big head, small body, stubby limbs

### Shared Eye Style (MUST be identical across all characters)
- Outer shape: Vertical oval (`<ellipse>` with ry > rx)
- White sclera with dark outline (character's darkest color)
- Pupil: Slightly offset upward (looking slightly up = dreamy/hopeful)
- Highlight 1: Large circle at top-left of pupil (main sparkle)
- Highlight 2: Smaller circle at bottom-right of pupil (secondary sparkle, 50% opacity)

### Shape Language
- ALL shapes must be rounded — no sharp edges anywhere
- Use `rx` on all `<rect>`, rounded `<path>` curves for everything
- Bodies are ellipses or rounded blobs, never angular
- This is critical for the 4+ age rating and friendly feel

### Line Weight
- Outer body outline: 2.5px stroke
- Inner details (patterns, spots): 1-1.5px stroke
- Subtle details (whiskers, shine marks): 0.5-1px stroke

### Color Rules
Each character has a 5-color palette:
1. **Base light** — background/aura color (lightest)
2. **Primary** — main body color
3. **Dark accent** — shell/spots/ear tips (darker shade of primary)
4. **Outline** — darkest shade for all strokes
5. **Belly/highlight** — lighter warm tone for belly, inner ears, cheek accents

### Expression System
Each character needs 4 expression states:
1. **Default** — personality-defining resting expression
2. **Joy** — eyes squeeze into crescents or sparkle bigger
3. **Scared** — eyes go huge, pupils shrink, character-specific panic reaction
4. **Speed** — squinted eyes, wind effect, streamlined pose

---

## Character Specifications

### 1. Turbo the Turtle (Main Character)
**Personality**: Slow on land but brave in the sky. Calm determination. The dreamer.

**Color Palette**:
| Role | Hex |
|------|-----|
| Base light | #E1F5EE |
| Primary (body) | #5DCAA5 |
| Dark (shell) | #1D9E75 |
| Outline | #085041 |
| Belly/highlight | #FAEEDA |

**Body Design**:
- Dome-shaped shell on back — this IS the rocket
- Short stubby limbs, round head poking forward
- Shell has simplified hexagonal pattern (5-6 segments, drawn with curved lines)
- Small pointed tail

**Signature Accessories**:
- Aviator goggles pushed up on forehead (brass/gold frame #BA7517, light blue lens #E6F1FB)
- Red aviator scarf (#E24B4A) trailing from neck, flowing behind during flight
- Both goggles and scarf are ALWAYS present — they are Turbo's identity

**Vehicle — Rocket Shell**:
- The shell itself transforms: small rocket boosters on both sides (metallic gray #888780)
- Main thruster at shell bottom center
- Flames: mint-to-orange gradient trail (#5DCAA5 → #EF9F27 → #E8593C)
- Character and vehicle are ONE unit — shell stays on Turbo's back

**Expressions**:
- Default: Calm determined eyes, small confident smile, goggles on forehead
- Joy: Eyes squeeze into crescents, scarf flutters up
- Scared: Eyes huge, retreats slightly into shell (shell rises to partially cover head)
- Speed: Eyes squint, scarf streams straight back, wind lines around body

---

### 2. Pip the Penguin
**Personality**: Tiny but fierce. Energetic cheerleader. Always excited.

**Color Palette**:
| Role | Hex |
|------|-----|
| Base light | #E6F1FB |
| Primary (tuxedo) | #378ADD |
| Dark (back) | #185FA5 |
| Outline | #0C447C |
| Belly | #FFFFFF |

**Body Design**:
- Compact oval body, upright posture
- Sky blue tuxedo pattern (NOT black — this differentiates from generic penguin designs)
- White belly in classic tuxedo shape
- Tiny flipper wings sticking out at sides, posed UP when excited
- Orange feet (#EF9F27) and small pointed beak (#EF9F27)
- Blush marks on cheeks (#F0997B, 40% opacity)

**Signature Details**:
- Small tuft of darker feathers on head like a mohawk (#185FA5)
- Beak often open mid-cheer (show orange interior #D85A30)
- Body tilts forward — always ready to go

**Vehicle — Propeller Backpack**:
- Small mechanical backpack with brass rivets (#BA7517)
- Two propeller blades on top, leaf/paddle shaped (metallic gray #B4B2A9)
- Center cap is brass (#BA7517)
- Visible chest straps (#5F5E5A)
- Propeller has a slight wobble — charming, not perfect
- Trail: Blue exhaust sparkles (#85B7EB, varying opacity)

**Expressions**:
- Default: Wide eager eyes, beak open in excitement, flippers up
- Joy: Jumps up, flippers spread wide, eyes sparkle
- Scared: Flippers cover face, peeking through gap between them
- Speed: Streamlined torpedo pose, flippers pinned back, beak closed

---

### 3. Nutty the Hamster
**Personality**: Comic relief. Cheeks always stuffed. Boundless curiosity. Mischief maker.

**Color Palette**:
| Role | Hex |
|------|-----|
| Base light | #FAEEDA |
| Primary (fur) | #EF9F27 |
| Dark (accents) | #BA7517 |
| Outline | #633806 |
| Belly stripe | #FAC775 |

**Body Design**:
- Round potato-shaped body — almost a perfect circle
- Oversized puffy cheeks (THE defining feature)
- ASYMMETRIC cheeks: right cheek is noticeably bigger than left (more stuffed)
- Tiny round ears on top with pink inner ears (#F5C4B3)
- Very short limbs, almost no neck
- Small stubby tail (round fluffball)

**Signature Details**:
- One eye slightly bigger than the other (right eye larger = mischief)
- Whiskers: 3 per side, thin lines (#633806, 35% opacity)
- Tiny paw with visible pad lines
- Seeds and crumbs particles float around during flight

**Vehicle — Acorn Helicopter**:
- Giant acorn cap as cockpit rim (dark brown #854F0B)
- Acorn body below with tiny windows (#FAC775)
- Stem on top is rotor axis, leaf-shaped blades (#97C459 with #3B6D11 veins)
- Nutty sits inside with head and upper body poking out
- Trail: Golden sparkles and floating seeds

**Expressions**:
- Default: Wide-eyed wonder, one eye bigger, cheeky grin
- Joy: Both cheeks puff even bigger, eyes close to happy crescents
- Scared: Cheeks suddenly deflate, eyes spiral/swirl pattern
- Speed: Cheeks flatten from wind resistance, seeds fly out behind

---

### 4. Mochi the Cat
**Personality**: Tsundere. Acts cool and unbothered but secretly terrified of heights. Elegant.

**Color Palette**:
| Role | Hex |
|------|-----|
| Base light | #EEEDFE |
| Primary (fur) | #CECBF6 |
| Dark (ear tips, tail tip) | #534AB7 |
| Outline | #3C3489 |
| Belly/inner ear | #ED93B1 |

**Body Design**:
- More graceful proportions than other characters (slightly slimmer, 2.5:2 head:body)
- Elegant pointed ears with pink inner ears and dark purple tips
- Long curling S-curve tail — visual flourish, tip is darkest purple
- Soft lavender-gray fur overall

**Signature Details**:
- Half-lidded eyes (THE defining feature — the "unimpressed" look)
- Cat-like vertical pupil hint (dark ellipse inside regular pupil)
- ω (omega) shaped mouth — classic cat mouth, slightly smug
- Small star marking on forehead (#7F77DD, 45% opacity)
- Bell collar: red ribbon (#E24B4A) with gold bell (#EF9F27)
- Whiskers: 2 per side, elegant thin lines
- Paw beans visible: pink toe pads (#ED93B1)

**Vehicle — Cushion Hot Air Balloon**:
- Round cat-bed-shaped basket with plush edges (#AFA9EC)
- Cushion stitch lines on basket body
- Balloon above: smooth rounded shape (#CECBF6) with panel lines
- Subtle paw-print pattern on balloon (#7F77DD, 20% opacity)
- Thin elegant ropes connecting basket to balloon (#7F77DD)
- Lavender flame heating the balloon (#AFA9EC → #7F77DD)
- Mochi lounges in the basket, paws draped over edge
- Trail: Small sparkle stars (#AFA9EC, varying opacity)

**Expressions**:
- Default: Half-lidded cool eyes, ω mouth, one paw draped elegantly
- Joy: Tries to stay cool but tail wiggles uncontrollably, ears perk slightly
- Scared: Eyes go HUGE (full open, tiny pupils), fur spikes on tail (bottle brush), claws out
- Speed: Squints elegantly, tail streams behind like a ribbon

---

### 5. Bounce the Frog
**Personality**: Pure optimist. Thinks EVERYTHING is amazing. Jumps first, thinks never. Endless energy.

**Color Palette**:
| Role | Hex |
|------|-----|
| Base light | #EAF3DE |
| Primary (skin) | #97C459 |
| Dark (spots) | #639922 |
| Outline | #27500A |
| Belly/underside | #C0DD97 |

**Body Design**:
- Wide flat head with protruding eyes on top (bulging frog eyes made cute)
- Wide mouth spanning nearly full face width — ALWAYS grinning
- Head and body almost merge — barely any neck distinction
- Powerful bent back legs (ready-to-jump pose)
- Webbed hands and feet (simple V-shaped separations)
- 3 dark green spots on back (simple circles)
- Yellowish belly spots

**Signature Details**:
- Enormous grin is THE defining feature — the biggest smile of all 6 characters
- Eyes are the largest of all characters (bulging frog eyes)
- Tongue occasionally peeks out (red #E24B4A, small curved tip)
- Blush marks on cheeks (#F0997B, 35% opacity)

**Vehicle — Lily Pad Glider**:
- Oversized lily pad with curled edges forming natural wing shape
- Leaf veins glow with green energy (#C0DD97)
- V-notch in the leaf (classic lily pad shape)
- Lotus flower at the front as headlight (#F5C4B3 petals, #ED93B1 inner, #EF9F27 center)
- Bounce sits cross-legged on top
- Trail: Water droplets catching light (#85B7EB, varying sizes and opacity)

**Expressions**:
- Default: Enormous grin, tongue tip peeking, bulging happy eyes
- Joy: Eyes close to pure crescents, mouth opens even wider
- Scared: Eyes bulge to COMICAL size (2x normal), pupils tiny dots, mouth goes "O"
- Speed: Streamlined with legs trailing behind like a skydiver, grin persists

---

### 6. Hoppy the Bunny
**Personality**: Shy but adventurous. Whispers courage to herself. Quietly brave. Tender-hearted.

**Color Palette**:
| Role | Hex |
|------|-----|
| Base light | #FAECE7 |
| Primary (fur) | #F0997B |
| Dark (ear inner, accents) | #D85A30 |
| Outline | #712B13 |
| Belly/chest | #F5C4B3 |

**Body Design**:
- Long upright ears — THE defining feature (tallest silhouette of all 6)
- ASYMMETRIC ears: left ear upright, right ear droops slightly (endearing imperfection)
- Round fluffy body, cotton ball tail (white, fluffy cluster of circles)
- One ear droops/twitches when nervous
- White heart-shaped chest patch
- Fluffy cheek tufts on both sides

**Signature Details**:
- Slightly downcast eyes (shy) but with sparkle of bravery (extra tiny highlight dots)
- Cute "3" shaped mouth (small pursed lips — NO buck teeth)
- Gentle subtle smile line below the "3" mouth
- Paws often held together in front (shy clasping pose)
- Small flower accessory behind left ear (pink petals #ED93B1, #F5C4B3, gold center #EF9F27)
- Pink inner ears that get redder when flustered
- Bigger, warmer blush marks (#ED93B1, 30% opacity)
- Soft gentle eyebrows (slightly worried, 30% opacity)
- Nose has a small shine highlight

**Vehicle — Carrot Jet**:
- Streamlined carrot-shaped jet
- Pointed nose (carrot tip) at front, slightly darker (#BA7517)
- Leafy greens at the back form tail fins (multiple layered leaves #97C459, #639922)
- Cockpit carved into carrot midsection with a window (#FAC775)
- Window has a small shine line
- Orange-to-green gradient along the body
- Carrot ring grooves along body (curved lines, 40% opacity)
- Trail: Heart-shaped exhaust puffs (#F5C4B3, decreasing size and opacity)

**Expressions**:
- Default: Shy downcast eyes with sparkle, "3" mouth, paws clasped together, flower in ear
- Joy: BOTH ears perk up straight, eyes sparkle bigger, tiny happy wiggle
- Scared: Both ears fold flat against back, covers eyes with ears
- Speed: Ears stream behind like ribbons, fierce determined face emerges (the hidden brave side)

---

## Required Asset List
For each of the 6 characters, generate the following SVG files:

### Per Character (6 × 8 = 48 files total)
```
assets/characters/{name}/
├── {name}_default.svg          # Standing/sitting pose, default expression
├── {name}_joy.svg              # Joy expression
├── {name}_scared.svg           # Scared expression  
├── {name}_speed.svg            # Speed/flying expression
├── {name}_flying.svg           # Full character + vehicle, in-flight pose
├── {name}_icon.svg             # Head-only portrait for UI (selection screen)
├── {name}_silhouette.svg       # Solid color silhouette for loading/unlock screens
└── {name}_vehicle_only.svg     # Vehicle without character (for UI elements)
```

### File Naming Convention
Use lowercase names: `turbo`, `pip`, `nutty`, `mochi`, `bounce`, `hoppy`

### SVG Specifications
- **ViewBox**: 400 × 400 for full body poses, 200 × 200 for icons
- **No external dependencies**: All styles inline, no external CSS/fonts
- **Flat design**: No gradients except where specifically noted (flame trails)
- **Clean paths**: Minimize anchor points, optimize for rendering performance
- **Consistent anchor**: Character center at (200, 200) for full body, (100, 100) for icons

---

## App Icon Specification
The App Store icon (1024 × 1024px) should feature:
- **Turbo** as the main character (head and upper body)
- Rocket flames visible from shell
- Sky blue gradient background (#E6F1FB → #85B7EB)
- Goggles on forehead catching light
- Warm, inviting expression (default or joy)
- No text — icon only
- Export as PNG 1024×1024

---

## Screenshot Character Poses
For App Store screenshots (2868 × 1320px landscape), characters should be shown in:
1. **Character Selection Screen**: All 6 characters in a row, each in their icon form
2. **In-Flight Gameplay**: Turbo flying with rocket shell through clouds
3. **Multiple Characters Flying**: 3 characters flying in formation

---

## Technical Notes for Three.js Integration
These SVGs will be used in two ways:
1. **2D UI elements**: Character selection, menus, HUD — use SVGs directly via `react-native-svg`
2. **3D game models**: The flying poses will be converted to textured planes or sprite sheets for Three.js rendering

For Three.js sprites:
- Export additional PNG versions at 512×512 resolution
- Include transparency (PNG-32)
- Characters face camera (billboard sprites)
- Consider sprite sheet format: 4 expressions in a 2×2 grid (1024×1024 total)

---

## Quality Checklist
Before finalizing each asset, verify:
- [ ] Eyes match the shared eye style (oval, dual highlight, consistent pupil placement)
- [ ] Head-to-body ratio is approximately 3:2
- [ ] All shapes are rounded — no sharp edges
- [ ] Signature accessory is present (goggles, mohawk, asymmetric cheeks, star mark + bell, tongue, flower + droopy ear)
- [ ] Colors match the specified palette exactly
- [ ] Character is recognizable from silhouette alone
- [ ] Vehicle design integrates naturally with character
- [ ] Expression is clear and readable at small sizes (64×64 minimum)
- [ ] No copyright-infringing similarities to existing characters
- [ ] SVG is optimized (no unnecessary groups, minimal path complexity)
