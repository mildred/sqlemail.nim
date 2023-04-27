disputatio
==========

Disputatio is a web document server, built to be federated (but not yet
implemented to) that allows anyone to create documents and comment to documents.
It allows arbitrary moderation structure where anyone can follow a moderator or
another.

Wiki Features:

- Provides wiki features to allow creating and updating articles
- Allow articles to be moderated by different people creating different views of
  the same article depending on the point of view you have or you want to
  follow.
- Allow discussions on each article paragraph, and nested discussion within
- Allow complex moderation, see FAQ

Discussion features:

- Allow public and private groups (no encryption is planned for now)
- Decentralize discussions allowing to change instances if an instance becomes
  hostile to a group, providing freedom of speech.

Roadmap
-------

### Immediate TODO ###

- display articles in a group
- display vote result for articles in a group
- rework how articles are working, possibly rename articles to posts:
    - articles is a list of paragraphs
    - articles have an author (group_guid + local_user_id)
    - articles can be created as part of a reply (article_guid, group_guid)
    - articles can be reposted to any group (group_guid + local_user_id)
    - articles can have modifications with an author (parent_article_guid,
      group_guid + local_user_id). Modification can only happen where an article
      was already created (author) or reposted.
    - articles are only accessible by members of the groups where an article is
      originally posted (author), reposted, or modified
    - any group where the article appears or is replied to should be notified
      about reposts or modifications
    - in the group view, it should be possible to access the public groups where
      the article is reposted. It should be possible to access the article
      history too.
- articles cannot compute a guid because user id cannot be embedded (user id is
  never static)
- TODO: link every article to a moderation group
- TODO: create a default moderation group for every user where the user is the
  only member of the group
- TODO: handle moderation groups where messages in the group cannot be
  discovered using the group id (you need to know the article id before)
  or should that be handled at the post level when the article is associated to
  a group, a boolean telling if the post should be accessible from the group
  (knowing the group id) or only if the article id is known.
- TODO: handle unique user id within a moderation group (nickname but that does
  not change)
- TODO: serialize user id in article using the unique member id of the
  moderation group the article belongs to

### Short Term ###

- [ ] Investigate using Mummy rather than Prologue
- [x] Basic log-in via OTP (auth app or e-mail)
- [x] Basic page creation
- [ ] Basic page viewing
- [x] Basic group creation
- [ ] UI to create default user groups: "Create public|private identity"
- [ ] Basic display of group
- [ ] Basic posting articles to a group
- [ ] Ability to join groups by their guid
- [ ] Basic display of articles in a group
- [ ] Controls to allow group members to vote for an article in a group
- [ ] Publication of groups to subjects
- [ ] Pod moderation overlay (necessary once public groups exists, not before)
- [ ] Think more about private messages and public messages. Allow replies to
  public objects to be private. Define clearly which messages are public and
  which are private. Private messages can only be accessed by people who knows a
  group guid. Public messages can be accessed recursively from public objects
  (subject). Have the ability to make whole groups public for discovery.
- [ ] Ability to terminate a group and point to another group that will
  continue. This allows inviting new members without giving them access to the
  history. To remove members without giving them history, the invitation to the
  new group must be given to only those we want to keep and the link should be
  made from the new group to the old.

### Long Term ###

- Add federation
- Add Encryption
- Add SMTP transport and be compatible with DeltaChat?

FAQ
---

### Why federation and not decentralization? ###

The problem with decentralisation is the availability of the data. People do not
want to have their devices constantly connected and do not want to store all
their chat history on their device.

Federation is not so much a problem when users have the easy ability to move to
another server at any time when convenient. This is the idea beind disputatio:
the user subscribes to a new pod and links its new account with the old, all
discussions are now duplicated on the new pod. Now the user removes the old
account on the old pod and the old pod does not have access to the content any
more.

### Why not encrypt at start? ###

Because this is difficult to do it right.

Because the main focus is to have non secret discussions on the platform.
Private discussions are only as private as their members do keep the privacy
anyway.

Also, if you don't trust your pod, it's easy to change the pod. If you don't
trust other users' pods then this means you don't trust the other users. TODO:
have a feature to restrict the participating pods in a private group.

### Why this moderation scheme? ###

The idea is to be able to moderate content (because unmoderated content is not
possible and one way or another, you will be forced to moderate) while keeping
the ability to change the moderator you trust.

Basic rules is:

- You should not be forced to accept a moderator you don't agree with. If you
  want to access content that a moderator is blocking, you should be able to
  subscribe to another moderator that is closest to your point of view.

- Pods should not be forced to host or participate in content that they
  disapprove, and as such, pods should have the ability to follow a global
  moderation group that will prevent unwanted content from the pod.

- Users should noe be forced to stay on a pod that moderates content they want
  to see, as such changing your account to another pod should be easy.

What's nice is that disputatio, originally thought as a wiki-like platform with
a way to get a diverse set of point of views can not be seen as a discussion
platform, where moderation groups becomes discussion groups.

Data Structure
--------------

See src/db/migration.nim. Data structure is such that it can be shared with
other instances.

Objects have both global ids that are content addressing identifiers and private
ids for the database access. Some objects are only a part of another object
(such as patch items) and do not have a global id other tan the global id of
their parent object.

- pod: a disputatio instance, it has a public URL

- users: a user is private to a pod but it can define alias (in same pod or
  other pods). Aliases are different user accounts but everywhere relevant, a
  list of user alias is used to mean a single pysical person.

- article: a piece of content to be shared associated with some author and
  possibly linked to a reply source. The content is the associated patch. The
  reply source can be of different types (subject, article, paragraph)

  The author of an article is a group or a member of a group. No matter the
  group type. The group name and the member nickname is used to display the
  author name.

  The article is published in a group as a member of that group (optional if it
  is an open group). If the group is private, the message can only be seen to
  the closed members of that group. If the group is unlisted, the messages can
  only be seen by those who have the id of the group. If the group is public,
  the message can be seen also by fetching the public replies of the object the
  article responds to.

  An article has an initial score set to 1 but the author can lower it to make
  the post invisible by default.

- patch: a list of ordered paragraphs. The patch can have a parent patch where
  it takes its content from (source control) and a list of items which are
  ordered. Patch items are directly linked with paragraphs.

- paragraph: a part of an article with some block structure and some text.
  Paragraps are separated from patch items to allow deduplicating content. The
  order of a paragraph can be different but the paragraph itself can be
  identical.

- post/article: this is a replacement model for articles. A post is a list of paragraphs
  authored by some user (group_guid + local_user_id). A post is included in a
  group by a vote (group_guid, local_user_id, vote).

  If the group where the post is shown (the group in the vote object) is the
  same as the author group, the post is shown as being authored on this group.
  Else it is shown as being reposted from where it was authored.

  The list of groups where the post has been voted is accessible from the
  interface, except for non private groups where the current user is not part
  of. it is possible to show those groups.

  A post can reference another post it replies to. The post being replied to is
  only accessible if from a public group or a group where the current user is a
  member of.

  A post can be modified. The modified post author group must be a group where
  the original post appears. The modified post can only add paragraphs and must
  preserve the original paragraphs order. Original paragraphs can be marked as
  deleted (but must still be referenced) and other paragraphs can be marked as
  being replaced by their sibling.

  Vote to individual paragraphs can restore old paragraphs

  Modified posts are only shown if the modification comes from the same user. if
  the modification comes from a different user, a link should be shown to see
  the modified post wiki-style. Then the post is shown full-page with comments
  and authoring info for each individual paragraph is shown.

  In the wiki-style page, modifications should be shown from all groups the user
  has access to, but shown/hidden paragraphs should be shown depending on the
  current group. The group becomes effectively a moderation group.

  Modifications being append-only, it ensures a conflict free merge from many
  modifications. New paragraphs should be ordered in a deterministic order
  (guid?)

- subject: a public name. Its there to be associated with articles and create a
  wiki-like application. It is to be used in the context of groups and users but
  the subject itself is not linked to those.

  User subjects is linked to the last article the user posted with a reply to
  the subject

  Group subjects is linked to the last article the group posted with a positive
  moderation with a reply to the subject

- groups (items): a group is a virtual object that represents a groups of users
  that share a common editorial history. The group is defined by its first item.
  Groups is a chain or items that reference each their parent. A group item
  defines the moderation policy, the group members and their weight in the
  moderation. Adding an item to a group requires satisfying control conditions
  to ensure that the group cannot be hijacked. The seed userdata is there to
  generate unique group ids

  Groups can be private, unlisted or public. Guests can post to unlisted or
  public groups and their messages can have a default weight making them visible
  without mederatio nfrom the group.

- group members: a group member has a local id for the scope of the group and an
  updatable nickname. It also has a weight defining the score of the articles
  posted. A member has a list of identities (pair of pod URL and local user id)

  TODO: add a boolean to tell if the member allows the group to be considered
  public. If all members agree with that then the group is made public with the
  subject defined in the group item.

- group vote TODO: this object associates an article with a group. The vote
  object contains a number that is multiplied by the member weight on the group
  to determine the weighted vote of this user for this content. Multiple members
  can vote for an article in a group and the total weighted vote for the article
  is the sum of all individual weighted votes. if the total weighted vote is
  positive, the content is shown.

  Members of groups can only vote if their weight is >= 0. Their vote is
  multiplied by their weight. Effectively giving a negative weight to a member
  is blacklisting and a 0 weight is greylisting. Negative votes will bring the
  articles scores down and positive votes will bring the articles scores up.

  TODO: add features to a vote in a group. A `pin` vote will pin the message at
  the top, a `title` / `description` feature will change the group title or
  description. Or should those features be included in the article voted??? TODO

  TODO: If the vote is performed to a subject and not an article, it publishes
  the group with the subject name and makes it public. This is a special vote
  and all members of the group must vote to make the group public.

  The computed score of an article is computed by:
  - take the group moderation default score
  - add each vote of the group members:
      - all group member votes are added together and capped -1..+1
      - the member votes (-1..+1) is multiplied by the member weight
      - if the member weight is <= 0, the vote is not counted

  TODO: remove the article initial score

  The vote applies to an article paragraph if a paragraph_rank is specified.

  TODO: is it relevant to apply a vote to a paragraph outside of the context of
  an article?

Moderation algorithms
---------------------

A group can be public, public and moderated, read-only or private.

- Public groups have their `others_members_weight` set to something other than 0
  to allow anyone to post content to a group. Posting content to a group is
  equivalent to voting for it. Anyone can downvote some content to hide it.
  Before anyone can post to the group, it must first register as a member with
  its weight set to `others_members_weight`.

- Public moderated groups have their `others_members_weight` set to 0 and
  `moderation_default_score` set to something other than 0. Posting content to
  such a group is allowed by anyone by voting for the content. The vote will not
  have any effect on the content score other than including it in the set of
  articles published. Any group member can downvote the content to moderate it
  away. Before anyone can post to the group, it must first register as a member
  with its weight set to `others_members_weight` (0)

- Public read-only groups have their `others_members_weight` and their
  `moderation_default_score` set to 0. Only the members can post articles to the
  group and those are visible to anyone

- Private groups are not yet implemented but will need cryptography to encrypt
  articles to group members only. In the meantime, private groups are only as
  private as the pods of their members is not making the group discoverable.

- Single user groups are used to handle posts from a single user and handle pod
  migration if needed in the future. Such a group is created by default with
  every user and has a single member, the user. `others_members_weight` is set
  to 0 to ensure that only the user can be part of the group and
  `moderation_default_score` is set to 0 too.

Even if groups are indicated public, messages should be considered public
correspondance only if it responds (even indirectly) to a public object
(subjects). Else posts are private correspondance (just as e-mail).

Whole groups can be considered public if the group itself is linked to a public
object (subject). This will make a group publicly discoverable by a search in
the subject namespace. This can only be made at group creation, else messages
exchanged early (considered private) will be made public without the permission
from everyone. TODO

Updating groups
---------------

Any member of a group can update the group by adding a group item following some
rules:

- adding a member can be done by anyone. The new member weight can not be any
  greater than the posting member
- TODO: adding members to open groups
- adding a member with a nickname already taken must be done by the member with
  the same nickname. The weight must be identical.
- removing a member can only be done only by the member itself. TODO, should it
  be possible?
- changing the others_member_weight: TODO (not more than member weight)
- changing the moderation_default_score: TODO (only if member weight > 0)
- removing another member: TODO, should it be possible? (only if its weight is
  less than our weight)
- making a group public (linking it with a subject) requires approval from all
  members.

The pod that receives the new group check those rules. if federation is
implemented, authoring the group items will be necessary and signature from the
member private key will be required. This means that a key pair must be
generated for each group member.

In the meantime, other pods accept new group items from any pod listed in the
group members provided that there exists a member with this pod URL that has the
right to add the group item.
