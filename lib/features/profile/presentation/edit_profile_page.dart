import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/widgets/common.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/auth/presentation/session_cubit.dart';
import 'package:bookmarkd/features/profile/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final Profile _original = context.read<SessionCubit>().profile!;
  late Profile _profile = _original;
  late final _username = TextEditingController(text: _profile.username);
  late final _name = TextEditingController(text: _profile.displayName);
  late final _bio = TextEditingController(text: _profile.bio);
  late final _goal = TextEditingController(text: _profile.readingGoal?.toString() ?? '');
  late bool _private = _profile.isPrivate;
  bool _busy = false;
  bool _saving = false;

  bool get _dirty {
    final o = _original;
    return !_saving &&
        (_username.text.trim() != o.username ||
            _name.text.trim() != (o.displayName ?? '') ||
            _bio.text.trim() != (o.bio ?? '') ||
            _goal.text != (o.readingGoal?.toString() ?? '') ||
            _private != o.isPrivate ||
            _profile.avatarUrl != o.avatarUrl);
  }

  @override
  void dispose() {
    for (final c in [_username, _name, _bio, _goal]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showMessage(context, AppFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePhoto() => _guard(() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (file == null) return;
    final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    final url = await sl<ProfileRepository>().uploadAvatar(_profile.id, await file.readAsBytes(), extension: ext);
    setState(() => _profile = _profile.copyWith(avatarUrl: () => url));
  });

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await _guard(() async {
      final repo = sl<ProfileRepository>();
      final username = _username.text.trim();
      if (username != _profile.username && !await repo.isUsernameAvailable(username, exceptUserId: _profile.id)) {
        throw const AppFailure.conflict('That username is taken.');
      }
      String? orNull(String s) => s.trim().isEmpty ? null : s.trim();
      final saved = await repo.updateProfile(
        _profile.copyWith(
          username: username,
          displayName: () => orNull(_name.text),
          bio: () => orNull(_bio.text),
          readingGoal: () => int.tryParse(_goal.text),
          isPrivate: _private,
        ),
      );
      if (!mounted) return;
      context.read<SessionCubit>().profileUpdated(saved);
      showMessage(context, 'Profile saved');
      context.pop();
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    dirty: _dirty,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _form,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(Space.gutter),
          children: [
            Center(child: AppAvatar(profile: _profile, size: 96)),
            Center(
              child: TextButton(onPressed: _busy ? null : _changePhoto, child: const Text('Change photo')),
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _username,
              validator: validateUsername,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Username', prefixText: '@'),
            ),
            const SizedBox(height: Space.sm),
            TextFormField(
              controller: _name,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: Space.sm),
            TextFormField(
              controller: _bio,
              maxLength: 280,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            const SizedBox(height: Space.sm),
            TextFormField(
              controller: _goal,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                final n = int.tryParse(v);
                return n == null || n < 1 || n > 1000 ? 'Between 1 and 1000' : null;
              },
              decoration: const InputDecoration(labelText: 'Books to read this year (optional)'),
            ),
            const SizedBox(height: Space.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _private,
              activeThumbColor: context.colors.accent,
              onChanged: (v) => setState(() => _private = v),
              title: const Text('Private profile'),
              subtitle: const Text('Only you can see your library, reviews and activity.'),
            ),
          ],
        ),
      ),
    ),
  );
}
