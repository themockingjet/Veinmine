using System;
using System.Collections.Generic;
using HarmonyLib;
using UnityEngine;

namespace Veinmine
{
    internal readonly struct MiningEffectsState
    {
        private readonly bool _suppressed;
        private readonly EffectList _destroyedEffect;
        private readonly EffectList _hitEffect;

        public MiningEffectsState(bool suppressEffects, EffectList destroyedEffect, EffectList hitEffect)
        {
            _suppressed = suppressEffects;
            _destroyedEffect = destroyedEffect;
            _hitEffect = hitEffect;
        }

        public void Restore(ref EffectList destroyedEffect, ref EffectList hitEffect)
        {
            if (!_suppressed)
            {
                return;
            }

            destroyedEffect = _destroyedEffect;
            hitEffect = _hitEffect;
        }
    }

    [HarmonyPatch(typeof(MineRock), nameof(MineRock.Damage))]
    static class MineRockDamagePatch
    {
        static bool Prefix(MineRock __instance, HitData hit)
        {
            if (hit == null || !VeinMinePlugin.veinMineKey.Value.IsKeyHeld())
            {
                return true;
            }

            Player? player = Player.GetClosestPlayer(hit.m_point, 5f);
            if (player == null ||
                hit.m_attacker != player.GetZDOID() ||
                __instance.m_hitAreas == null ||
                __instance.m_nview == null ||
                !__instance.m_nview.IsValid())
            {
                return true;
            }

            float radius = VeinMinePlugin.progressiveMode.Value == VeinMinePlugin.Toggle.On
                ? VeinMinePlugin.progressiveMult.Value * Functions.GetSkillLevel(player.GetSkills(), Skills.SkillType.Pickaxes)
                : float.PositiveInfinity;

            foreach (Collider area in __instance.m_hitAreas)
            {
                if (!__instance.m_nview.IsValid())
                {
                    break;
                }

                if (area == null)
                {
                    continue;
                }

                int areaIndex = __instance.GetAreaIndex(area);
                if (areaIndex < 0 ||
                    (area != hit.m_hitCollider && Vector3.Distance(hit.m_point, area.bounds.center) > radius))
                {
                    continue;
                }

                HitData sectionHit = hit.Clone();
                sectionHit.m_hitCollider = area;
                sectionHit.m_point = area.bounds.center;
                if (VeinMinePlugin.progressiveMode.Value == VeinMinePlugin.Toggle.Off)
                {
                    sectionHit.m_damage.m_pickaxe = __instance.m_nview.GetZDO().GetFloat($"Health{areaIndex}", __instance.m_health);
                }

                __instance.m_nview.InvokeRPC("Hit", sectionHit, areaIndex);
            }

            return false;
        }
    }

    [HarmonyPatch(typeof(MineRock), "RPC_Hit")]
    static class MineRockHitEffectsPatch
    {
        static void Prefix(
            MineRock __instance,
            HitData hit,
            int hitAreaIndex,
            ref EffectList ___m_destroyedEffect,
            ref EffectList ___m_hitEffect,
            out MiningEffectsState __state)
        {
            __state = default;
            if (hit == null ||
                !VeinMinePlugin.veinMineKey.Value.IsKeyHeld() ||
                VeinMinePlugin.removeEffects.Value != VeinMinePlugin.Toggle.On)
            {
                return;
            }

            Player? player = Player.GetClosestPlayer(hit.m_point, 5f);
            if (player == null ||
                hit.m_attacker != player.GetZDOID() ||
                __instance.m_nview == null ||
                !__instance.m_nview.IsValid() ||
                __instance.GetHitArea(hitAreaIndex) == null)
            {
                return;
            }

            __state = new MiningEffectsState(true, ___m_destroyedEffect, ___m_hitEffect);
            ___m_destroyedEffect = new EffectList();
            ___m_hitEffect = new EffectList();
        }

        static void Postfix(
            ref EffectList ___m_destroyedEffect,
            ref EffectList ___m_hitEffect,
            MiningEffectsState __state)
        {
            __state.Restore(ref ___m_destroyedEffect, ref ___m_hitEffect);
        }

        static Exception Finalizer(
            Exception __exception,
            ref EffectList ___m_destroyedEffect,
            ref EffectList ___m_hitEffect,
            MiningEffectsState __state)
        {
            __state.Restore(ref ___m_destroyedEffect, ref ___m_hitEffect);
            return __exception;
        }
    }

    [HarmonyPatch(typeof(MineRock5), nameof(MineRock5.Damage))]
    static class MineRock5DamagePatch
    {
        static bool Prefix(MineRock5 __instance, ZNetView ___m_nview, HitData hit)
        {
            if (hit == null || !VeinMinePlugin.veinMineKey.Value.IsKeyHeld())
            {
                return true;
            }

            Player? player = Player.GetClosestPlayer(hit.m_point, 5f);
            if (player == null || hit.m_attacker != player.GetZDOID())
            {
                return true;
            }

            ItemDrop.ItemData currentWeapon = player.GetCurrentWeapon();
            if (currentWeapon == null ||
                currentWeapon.GetDamage().m_pickaxe <= 0f ||
                hit.m_damage.m_pickaxe <= 0f ||
                hit.m_toolTier < __instance.m_minToolTier)
            {
                return true;
            }

            __instance.SetupColliders();
            __instance.LoadHealth();
            if (___m_nview == null || !___m_nview.IsValid() || __instance.m_hitAreas == null)
            {
                return true;
            }

            float radius = VeinMinePlugin.progressiveMode.Value == VeinMinePlugin.Toggle.On
                ? VeinMinePlugin.progressiveMult.Value * Functions.GetSkillLevel(player.GetSkills(), Skills.SkillType.Pickaxes)
                : float.PositiveInfinity;
            List<MiningTarget> targets = new();

            foreach (var area in __instance.m_hitAreas)
            {
                if (area == null || area.m_collider == null || area.m_health <= 0f)
                {
                    continue;
                }

                Vector3 point = area.m_collider.bounds.center;
                if (area.m_collider != hit.m_hitCollider && Vector3.Distance(hit.m_point, point) > radius)
                {
                    continue;
                }

                int areaIndex = __instance.GetAreaIndex(area.m_collider);
                if (areaIndex >= 0)
                {
                    targets.Add(new MiningTarget(areaIndex, area.m_collider, point));
                }
            }

            if (targets.Count == 0)
            {
                return true;
            }

            targets.Sort((left, right) =>
                (left.Point - hit.m_point).sqrMagnitude.CompareTo((right.Point - hit.m_point).sqrMagnitude));

            foreach (MiningTarget target in targets)
            {
                if (!___m_nview.IsValid() ||
                    (currentWeapon.m_shared.m_useDurability && currentWeapon.m_durability <= 0f))
                {
                    break;
                }

                HitData sectionHit = hit.Clone();
                sectionHit.m_hitCollider = target.Collider;
                sectionHit.m_point = target.Point;
                if (VeinMinePlugin.progressiveMode.Value == VeinMinePlugin.Toggle.Off)
                {
                    sectionHit.m_damage.m_pickaxe = Mathf.Max(sectionHit.m_damage.m_pickaxe, 1_000_000f);
                }

                if (VeinMinePlugin.enableSpreadDamage.Value == VeinMinePlugin.Toggle.On)
                {
                    sectionHit = Functions.SpreadDamage(sectionHit, player);
                }

                ___m_nview.InvokeRPC("RPC_Damage", sectionHit, target.AreaIndex);
            }

            return false;
        }

        private readonly struct MiningTarget
        {
            public readonly int AreaIndex;
            public readonly Collider Collider;
            public readonly Vector3 Point;

            public MiningTarget(int areaIndex, Collider collider, Vector3 point)
            {
                AreaIndex = areaIndex;
                Collider = collider;
                Point = point;
            }
        }
    }

    [HarmonyPatch(typeof(MineRock5), nameof(MineRock5.DamageArea))]
    static class MineRock5DamageAreaPatch
    {
        static void Prefix(
            MineRock5 __instance,
            HitData hit,
            int hitAreaIndex,
            ref EffectList ___m_destroyedEffect,
            ref EffectList ___m_hitEffect,
            out DamageAreaState __state)
        {
            __state = default;
            if (hit == null || !VeinMinePlugin.veinMineKey.Value.IsKeyHeld())
            {
                return;
            }

            Player? player = Player.GetClosestPlayer(hit.m_point, 5f);
            ItemDrop.ItemData? weapon = player?.GetCurrentWeapon();
            MineRock5.HitArea? hitArea = __instance.GetHitArea(hitAreaIndex);
            if (player == null ||
                hit.m_attacker != player.GetZDOID() ||
                weapon == null ||
                hitArea == null ||
                hitArea.m_health <= 0f)
            {
                return;
            }

            bool suppressEffects = VeinMinePlugin.removeEffects.Value == VeinMinePlugin.Toggle.On;
            MiningEffectsState effects = new(suppressEffects, ___m_destroyedEffect, ___m_hitEffect);
            __state = new DamageAreaState(player, weapon, hitArea.m_health, effects);
            if (suppressEffects)
            {
                ___m_destroyedEffect = new EffectList();
                ___m_hitEffect = new EffectList();
            }
        }

        static void Postfix(
            HitData hit,
            ref EffectList ___m_destroyedEffect,
            ref EffectList ___m_hitEffect,
            DamageAreaState __state)
        {
            __state.Effects.Restore(ref ___m_destroyedEffect, ref ___m_hitEffect);
            if (!__state.IsVeinMined || __state.InitialHealth <= 0f || hit.GetTotalDamage() <= 0f)
            {
                return;
            }

            Skills skills = __state.Player.GetSkills();
            float skillIncreaseStep = Functions.GetSkillIncreaseStep(skills, Skills.SkillType.Pickaxes);
            float xpMultiplier = VeinMinePlugin.progressiveMode.Value == VeinMinePlugin.Toggle.On
                ? VeinMinePlugin.xpMult.Value
                : 1f;
            __state.Player.RaiseSkill(Skills.SkillType.Pickaxes, skillIncreaseStep * xpMultiplier);

            if (VeinMinePlugin.veinMineDurability.Value != VeinMinePlugin.Toggle.On ||
                !__state.Weapon.m_shared.m_useDurability)
            {
                return;
            }

            float durabilityMultiplier = Mathf.Max(0.01f, VeinMinePlugin.durabilityMult.Value);
            float durabilityLoss = VeinMinePlugin.progressiveMode.Value == VeinMinePlugin.Toggle.On
                ? __state.Weapon.m_shared.m_useDurabilityDrain *
                  ((120f - Functions.GetSkillLevel(skills, Skills.SkillType.Pickaxes)) / (20f * durabilityMultiplier))
                : __state.Weapon.m_shared.m_useDurabilityDrain;
            __state.Weapon.m_durability = Mathf.Max(0f, __state.Weapon.m_durability - durabilityLoss);
        }

        static Exception Finalizer(
            Exception __exception,
            ref EffectList ___m_destroyedEffect,
            ref EffectList ___m_hitEffect,
            DamageAreaState __state)
        {
            __state.Effects.Restore(ref ___m_destroyedEffect, ref ___m_hitEffect);
            return __exception;
        }

        private readonly struct DamageAreaState
        {
            public readonly Player Player;
            public readonly ItemDrop.ItemData Weapon;
            public readonly float InitialHealth;
            public readonly MiningEffectsState Effects;

            public bool IsVeinMined => Player != null && Weapon != null;

            public DamageAreaState(
                Player player,
                ItemDrop.ItemData weapon,
                float initialHealth,
                MiningEffectsState effects)
            {
                Player = player;
                Weapon = weapon;
                InitialHealth = initialHealth;
                Effects = effects;
            }
        }
    }
}
