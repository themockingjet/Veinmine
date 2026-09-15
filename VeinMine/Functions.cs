using UnityEngine;

namespace Veinmine
{
    class Functions
    {
        internal const float PoweredTreeDamage = 1_000_000f;

        public static float GetSkillIncreaseStep(Skills playerSkills, Skills.SkillType skillType)
        {
            if (playerSkills != null)
                foreach (var skill in playerSkills.m_skills)
                {
                    if (skill.m_skill == skillType)
                    {
                        return skill.m_increseStep;
                    }
                }

            return 1f;
        }

        public static float GetSkillLevel(Skills playerSkills, Skills.SkillType skillType)
        {
            if (playerSkills != null)
            {
                Skills.Skill skill = playerSkills.GetSkill(skillType);
                if (skill != null)
                {
                    return skill.m_level;
                }
            }

            return 1f;
        }

        public static float GetDistanceFromPlayer(Vector3 playerPos, Vector3 colliderPos)
        {
            return Vector3.Distance(playerPos, colliderPos);
        }

        public static bool TryPrepareTreeFellingHit(HitData hit)
        {
            if (hit == null ||
                VeinMinePlugin.enableTrees.Value != VeinMinePlugin.Toggle.On ||
                !VeinMinePlugin.veinMineKey.Value.IsKeyHeld())
            {
                return false;
            }

            Player? player = Player.GetClosestPlayer(hit.m_point, 5f);
            if (player == null || hit.m_attacker != player.GetZDOID())
            {
                return false;
            }

            ItemDrop.ItemData? weapon = player.GetCurrentWeapon();
            if (weapon == null ||
                weapon.GetDamage().m_chop <= 0f ||
                hit.m_damage.m_chop <= 0f)
            {
                return false;
            }

            hit.m_damage.m_chop = Mathf.Max(hit.m_damage.m_chop, PoweredTreeDamage);
            return true;
        }

        public static HitData SpreadDamage(HitData hit, Player player)
        {
            if (player == null)
            {
                return hit;
            }

            if (VeinMinePlugin.spreadDamageType.Value == VeinMinePlugin.SpreadTypes.Level)
            {
                float modifier = GetSkillLevel(player.GetSkills(), Skills.SkillType.Pickaxes) * 0.01f;
                hit.m_damage.m_pickaxe *= modifier;
            }
            else
            {
                ItemDrop.ItemData? weapon = player.GetCurrentWeapon();
                if (weapon == null) return hit;

                hit.m_damage.m_pickaxe = weapon.GetDamage().m_pickaxe;
                float distance = Vector3.Distance(player.GetTransform().position, hit.m_point);
                if (distance >= 2f) hit.m_damage.m_pickaxe /= distance * 1.25f;
            }

            return hit;
        }
    }
}