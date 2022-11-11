import templates

import ./common

func group_new*(): string = tmpli html"""
  <article>
    New Group
    <form method="POST" action="/@/">
      <input type="text" name="seed_userdata" placeholder="seed" />
      <input type="hidden" name="others_members_weight" value="0" />
      <input type="hidden" name="moderation_default_score" value="0" />
      <input type="submit" value="Create"/>
    </form>
  </article>
"""

