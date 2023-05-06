// store.js
// ========
//
// Extensions to Svelte stores
//
// Changelog
// ---------
// 2023-05-05: start this changelog, store.js taken from webmsg-webmail project
//

import { readable, writable, derived as derived_orig, get } from 'svelte/store';

export { readable, writable, get }

export function derived(stores, callback = null, ...args) {
  if (callback == null) {
    callback = (x) => x
  }
  if (stores instanceof Array) {
    stores = Array.from(stores, store => ( store == null ? readable(null) : store ))
  }
  return derived_orig(stores, callback, ...args)
}

export function async_derived(initial_value, store) {
  return fancy(initial_value).init(async (_, {set, add_finalizer}) => {
    const actual_store = (typeof store == 'function') ? await store() : await store
    if (!actual_store.subscribe) {
      set(actual_store)
    } else {
      add_finalizer(actual_store.subscribe(value => set(value)))
    }
  })
}

export async function ready(store, predicate) {
  return await new Promise((accept, reject) => {
    let keep_subscription = false
    let unsubscribe
    unsubscribe = store.subscribe(data => {
      if (predicate ? predicate(data) : data) {
        if (unsubscribe) unsubscribe()
        accept(data)
      } else {
        keep_subscription = true
      }
    })
    if (!keep_subscription) unsubscribe()
  })
}

// combine is a derived store that does nothing but concatenate the different
// stores together without any processing
export function combine(stores) {
  if (stores.subscribe) {
    stores = Array.from(arguments)
  }

  if (stores instanceof Array) {
    return derived(stores)
  } else {
    const names = []
    const store_arr = []
    for(const s of Object.keys(stores)) {
      names.push(s)
      store_arr.push(stores[s])
    }
    return derived(store_arr, (args) => {
      const res = {}
      for(let i = 0; i < names.length; i++) {
        res[names[i]] = args[i]
      }
      return res
    })
  }
}

// Fancy writable store that can derive from itself or other stores. Use
// similarly to a writable store but in addition you can call `derive()` on the
// store to register derive functions. `derive()` return the store itself so you
// can chain the calls.
//
// .derive(($store, set) => { ... })
// .derive(store1, ($store, $store1, update) => { ... })
// .derive([store1, store2, ...], ($store, [$store1, $store2, ...], update) => { ... })
//
// This callback is called when the store itself changes
//
//   $store:       the store value
//   update:       set function to update the store itself. If the argument is
//                 not a function it will behave as `set` instead
//   return value: if non undefined and non promise the store will be set to it
//
// Beware if calling set or returning non undefined value: this will trigger the
// callback a second time. Make sure that you do not create loops.
//
// .init(($store, update) => { ... })
//
// Calling init() will execute the callback when the store is initialized. If
// the callback needs to unregister something when the store it deinitialized,
// it can return an unsubscribe function. This is like the second parameter to
// writable() but you can define more than one function.
//
// If the store is already initialized, the callback will be called right away
// and its unsubscribe function will be called when deinitialized later.
//
// Also, it can return a Promise for the unsubscribe function if that is more
// convenient.
//
export function fancy(def_value, start) {
  let   started      = false
  let   starting     = false
  const starts       = [start]
  const unsubscribes = []
  let   countdown    = 1000 // recursivity protection


  const store = writable(def_value, (set) => {
    starting = true
    // countdown = 1000
    for(const start of starts) {
      if(! start) continue
      add_finalizer(start(set))
    }

    // Once all start functions are called, declare the store started
    // If a start function is pushed to the starts array during the starts array
    // iteration, it will be called.
    started  = true
    starting = false

    return unsubscribe
    function unsubscribe() {
      started = false
      while(unsubscribes.length > 0) {
        call_unsubscribe(unsubscribes.pop())
      }
    }
  })

  store.init = function(cb) {
    start = (set) => {
      const update = (arg, ...args) => {
        if (typeof arg == 'function') {
          return store.update(arg, ...args)
        } else {
          return set(arg, ...args)
        }
      }

      update.update        = store.update.bind(store)
      update.set           = set
      update.add_finalizer = add_finalizer
      update.derive        = (...args) => add_finalizer(derive(update, ...args))

      return cb(get(store), update)
    }

    starts.push(start)

    // If already started, start manually
    if (started) {
      add_finalizer(start(store.set.bind(store)))
    }

    return store
  }

  store.derive = function(parent_store, cb){
    store.init((_, update) => {
      return derive(update, parent_store, cb)
    })
    return store
  }

  store.log = function(cb) {
    const set = store.set.bind(store)
    store.set = function(...args) {
      cb(...args)
      return set(...args)
    }
    return store
  }

  store.validates = function(validates, message = "Validation failed for store") {
    const set = store.set.bind(store)
    store.set = function(...args) {
      if (! validates(...args)) throw message
      return set(...args)
    }
    return store
  }

  return store

  function derive(update, parent_store, cb) {
    if (typeof parent_store == 'function') {
      cb = parent_store
      parent_store = null
    } else if (parent_store instanceof Array) {
      parent_store = derived(parent_store)
    }

    let unsubscribe

    update.derive = null // derive inside a derive is a receipe for disaster
    // What we can do instead is to replace the derive stores
    if (parent_store != null) update.update_derive = (new_store) => {
      if (!new_store) {
        new_store = parent_store
      } else if (new_store instanceof Array) {
        new_store = derived(new_store)
      }
      if (unsubscribe) finalize_before_time(unsubscribe)
      unsubscribe = subscribe_derived(new_store)
      add_finalizer(unsubscribe)
    }

    unsubscribe = subscribe_derived(parent_store)
    return unsubscribe;

    function subscribe_derived(parent_store) {
      if (parent_store == null) {
        return store.subscribe(data => {
          const res = cb(data, update)
          if (res !== undefined && ! (res instanceof Promise)) update.set(res)
        })
      } else {
        return parent_store.subscribe(async parent_data => { 
          const res = cb(get(store), parent_data, update)
          if (res !== undefined && ! (res instanceof Promise)) update.set(res)
        })
      }
    }
  }

  function call_unsubscribe(unsub){
    if (unsub?.unsubscribe) return unsub.unsubscribe()
    else if (unsub) return unsub()
  }

  function sync_resolve(promise, cb) {
    if(countdown-- <= 0) throw "countdown"
    if (promise instanceof Promise) {
      promise.then(cb)
    } else {
      cb(promise)
    }
  }

  function add_finalizer(promise_unsub) {
    sync_resolve(promise_unsub, unsub => {
      if (!unsub) return
      if (starting || started) unsubscribes.push(unsub)
      else call_unsubscribe(unsub)
    })
  }

  function finalize_before_time(promise_unsub) {
    sync_resolve(promise_unsub, unsub => {
      if (!unsub) return
      if (starting || started) {
        const index = unsubscribes.indexOf()
        if (index >= 0) delete unsubscribes[index]
      }
      call_unsubscribe(unsub)
    })
  }
}

export class Inhibitor {
  constructor() {
    this.sem = 0
  }

  get inhibited() {
    return this.sem > 0
  }

  inhibit(cb) {
    try {
      this.sem++
      return cb()
    } finally {
      this.sem--
    }
  }
}

export function dig_store(defaultVal, stores, ...args) {
  return async_derived(defaultVal, async () => {
    let res = stores
    for(const arg of args) {
      res = res[await arg]
    }
    return res
  })
}

