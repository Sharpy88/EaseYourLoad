@@
-      _MoreCard(
-        icon: Icons.card_giftcard_outlined,
-        title: 'Gift ideas',
-        subtitle: '${gifts.length} ideas saved',
-        onTap: () => Navigator.push(
-          context,
-          MaterialPageRoute(
-            builder: (_) => IdeaPage(
-              title: 'Gift ideas',
-              items: gifts,
-              prompt: 'Add gift idea',
-              onChanged: onChanged,
-            ),
-          ),
-        ),
-      ),
+      _MoreCard(
+        icon: Icons.card_giftcard_outlined,
+        title: 'Gift ideas',
+        subtitle: '${gifts.length} ideas saved',
+        onTap: () => Navigator.push(
+          context,
+          MaterialPageRoute(
+            builder: (_) => const GiftsPage(),
+          ),
+        ),
+      ),
@@
-      _MoreCard(
-        icon: Icons.favorite_border,
-        title: 'Date night plans',
-        subtitle: '${dates.length} ideas saved',
-        onTap: () => Navigator.push(
-          context,
-          MaterialPageRoute(
-            builder: (_) => IdeaPage(
-              title: 'Date night plans',
-              items: dates,
-              prompt: 'Add date plan',
-              onChanged: onChanged,
-            ),
-          ),
-        ),
-      ),
+      _MoreCard(
+        icon: Icons.favorite_border,
+        title: 'Date night plans',
+        subtitle: '${dates.length} ideas saved',
+        onTap: () => Navigator.push(
+          context,
+          MaterialPageRoute(
+            builder: (_) => IdeaPage(
+              title: 'Date night plans',
+              items: dates,
+              prompt: 'Add date plan',
+              onChanged: onChanged,
+            ),
+          ),
+        ),
+      ),
+      _MoreCard(
+        icon: Icons.group,
+        title: 'Household & Invites',
+        subtitle: 'Invite and join household',
+        onTap: () => Navigator.push(
+          context,
+          MaterialPageRoute(
+            builder: (_) => const HouseholdPage(),
+          ),
+        ),
+      ),
