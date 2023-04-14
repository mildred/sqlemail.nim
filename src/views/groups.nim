import templates

import ../db/groups

func group_new*(): string = tmpli html"""
  <article>
    New Identity
    <form method="POST" action="/@/">
      <input type="text" name="name" placeholder="name" />
      <input type="hidden" name="_preset" value="identity" />
      <input type="submit" value="Create"/>
    </form>
  </article>
  <article>
    New Empty Group
    <form method="POST" action="/@/">
      <input type="text" name="name" placeholder="name" />
      <input type="text" name="seed_userdata" placeholder="seed" />
      <input type="text" name="self_nickname" placeholder="our nickname" />
      <select name="group_type">
        <option value="0">strict private group</option>
        <option value="1">unlisted private group</option>
        <option value="3">public group</option>
      </select>
      <select name="others_members_weight">
        <option value="0">Guest cannot post</option>
        <option value="1">Guest can post</option>
      </select>
      <select name="moderation_default_score">
        <option value="0">Guest posts are moderated by default</option>
        <option value="1">Guest posts are visible by default</option>
      </select>
      <input type="submit" value="Create"/>
    </form>
  </article>
"""

func group_list*(groups: seq[GroupItem]): string = tmpli html"""
  <p>Member of $(groups.len) groups</p>
  $if groups.len > 0 {
    <ul>
      $for group in groups {
        <li>
          <a href="/@$(group.guid)/">$(group.name)</a>
        </li>
      }
    </ul>
  }
  $(group_new())
"""


