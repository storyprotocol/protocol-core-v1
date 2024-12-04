Basic assumption: 
A license is to make a derivative

# Starting from Not a derivative

Bob owns IP1
1) If Bob adds 1 Policy in IP -> others can mint if they pass verifications ✅
2) If Bob doesn't set Policy in IP -> others can't mint✅
3) Bob can mint Licenses with whatever Policy in any of the above✅

4) Bob can add different policies on IP1 without compatibility checks. Others can mint licenses to make derivatives of IP1 from each different policy, as long as they pass the verifications✅

5) Bob can mint licenses with different policies, transfer to others, and the holders can make derivatives from each License, regardless of IP1 having several policies set✅
   
6) Bob has set P1 and P2 in IP1, and gets license(LE) with PolicyEmergence(PE) from Emergence's World Bible IP (IPE)
   Bobs wants to set IPE as parent of IP1

    6.1) If the policies that IP1 has are in conflict with PE, revert 🚧

    6.2) If the policies that IP1 has are not in conflict with PE, OK -> IP1 adds PE, IPE parent of IP1 🚧

    6.3) Bob disable conflicting policies, then Adds PE 🚧

# Starting from A Derivative

Bob owns IP1

Bob creates a license L1 with P1

Alice owns IP2

Alice burns L1, P1 is set in IP2

1. P1 does not allow for derivatives

    1.1. Don tries to mint a license from P1 in IP2 -> fails ✅

    1.2. Alice tries to mint a license from P1 in IP2 -> fails ✅

    1.3. Alice tries to set a policy --> fails ✅

        /*
         * Edge case:Alice buys the right from her licensor to make derivatives.
           Setting the parent again should work in this case, P2 should be.
         */

    1.4. Bob mints L2 with P2 (allows derivatives) and sends it to Alice 
         Alice burns L2 and P2 is set in IP2 
         Alice can mint now L3 with P2?

3. P1 allows for derivatives of this derivatives, but meaning P1 propagates down, no other can be set (reciprocal == true) 

    2.1. Don tries to mint a license from P1 in IP2 -> License mints, has P1 ✅

    2.2. Alice tries to mint a license from P1 in IP2 -> License mints, has P1 ✅

    2.3. Alice tries to set P2 in IP2 -> Fails, reciprocal means no different policies allowed, 
         and you cannot add the same policy twice ✅

# Setting multiple parents
Bob owns IP1, IP2 and IP3
Bob mints L1 with P1 from IP1
Bob mints L2 with P2 from IP2
Bob mints L3 with P3 from IP3
Alice owns IP4
Alice wants to burn L1,L2 and L3 to link as parents for IP4

1) Reciprocal

    1.1) All licenses have the same reciprocal policy -> OK, result has 1 Policy ✅

    1.2) Different policies, but at least 1 reciprocal -> Should Fail ✅

2) NonReciprocal

    2.1) All licenses have the same reciprocal policy -> OK, result has 1 Policy ✅

    2.2) Different policies, but at least 1 reciprocal -> Should Fail ✅


| Parameter               | Multi parent eval                                   | Reason                                                                                                            |
|-------------------------|-----------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| Attribution             | Indifferent                                         | Holder of all licenses must attribute the ones demanding it. Disputable                                           |
| Transferable            | Indifferent                                         | Property of the license, not the IP                                                                               |
| Commercial use          | Equal or revert                                     | One would infringe the other                                                                                      |
| Commercial attribution  | Indifferent                                         | Holder of all licenses must attribute the ones demanding it. Disputable                                           |
| Commercializers         | Indifferent                                         | OK if verification checks for all licenses succeed                                                                |
| Commercial Rev Share    | Indifferent                                         | Licensing process must set all. Verifications must pass                                                          |
| Derivatives             | Equal or revert                                     | One would infringe the other                                                                                      |
| Derivatives Attribution | Indifferent                                         | Holder of all licenses must attribute the ones demanding it. Disputable                                           |
| Derivatives Approval    | Indifferent                                         | OK if verification checks for all licenses succeed                                                                |
| Derivatives Reciprocal  | Equal or revert. If both true, policy must be equal | One would infringe the other                                                                                      |
| Derivatives Rev Share   | Indifferent                                         | Licensing process must set all. Verifications must pass                                                          |
| Territories             | All equal, or some empty and the rest equal         | All permissive is OK. Some permissive except some with same restrictions OK. Different restrictions is a conflict |
| Distribution Channels   | Same as previous                                    | Same as previous                                                                                                  |
| Content Restrictions    | Same as previous                                    | Same as previous                                                                                                  |


# INTEGRATION

| Demo Use Case          | Social Remixing                                     | Commercial Activity                                    |
|-----------------------|----------------------------------------------------|----------------------------------------------------|
| Purpose               | Allow users to add multiple layers of creativity to an original work, with appropriate attribution and control for the source creator | Monetize an original work                           |
| License flavor        | Non-commercial remix with attribution, reciprocal license | Permissionless commercial license with attribution  |
| What makes this unique? | Endless remixing - tracking all the uses of a work, and giving the creator full credit | Provides the creator with full control over the uses of her work, while allowing any 3rd party to appropriately use the work for fair economics |
| Parameters - all default EXCEPT | | |
| Attribution           | Tagged                                              | Tagged                                              |
| Derivatives          | Allowed-With-Attribution Allowed-With-Reciprocal License | |
| Commercial Use       |                                                      | Allowed-With-Attribution                           |
| License Fee          |                                                      | One-Time LicenseFee Actual fee TBD by Creator     |

P1 - Social Remixing
P2 - Commercial Activity

So we have:
- An original work A, has P1 and P2 set
- People can remix A into B and B into C, all of with P1
- P2 is permissionless (since it's set on A)
- B can buy License from A with P2 and link if it passes verifications
- C can buy License from A with P2 and link if it passes verification

- P2 is NOT permissionless (commercializers are set)

        /*
         * TODO: commercializer, whitelist or token gating
         */

- B can buy License from A with P2 and link if CommercializerHelper agrees
- C can buy License from A with P2 and link if CommercializerHelper agrees


# DISPUTED CASES

## Plagiarism

Bob owns IP1
Bob sets P1 in IP1 (he can, since he claims IP1 is original)
Alice owns IP2
Alice mints L1 from IP1-P1
Alice links IP2 to IP1 with L1

1. Don finds out IP1 plagiarizes his IP0

2. Don raises dispute against IP1 for plagiarism

3. Results after dispute passes:

    3.1) IP1 is labeled as plagiarism

    3.2) Bob cannot set policies in IP1

    3.3) Bob cannot mint licenses from IP1

    3.4) Alice cannot set policies in IP2

    3.5) Alice cannot mint licenses from IP2

        /*
         * TODO: Handle royalties distribution
         */


## Unattributed derivative

Bob owns IP1
Bob sets P1 in IP1 (he can, since he claims IP1 is original)
Alice owns IP2
Alice mints L1 from IP1-P1
Alice links IP2 to IP1 with L1

1. Don finds out IP1 is a clear derivative of his IP0

2. Don raises dispute against IP1 for unattributed derivative

3. Possible outcomes:

    3.1) Option 1:
        - Bob cannot set policies in IP1
        - Bob cannot mint licenses from IP1
        - Alice cannot set policies in IP2
        - Alice cannot mint licenses from IP2

        /*
         * TODO: Handle royalties distribution
         */

    3.2) Option 2:
        - IP1 is forced to set IP0 as parent
        - All policies from IP1 are disabled and IP0 policy is set instead

        /*
         * Does this propagate through children/royalties?
         */
