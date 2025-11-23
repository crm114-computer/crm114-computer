package app

import "testing"

func TestGreeting(t *testing.T) {
    got := Greeting()
    want := "welcome to crm114"
    if got != want {
        t.Fatalf("Greeting() = %q, want %q", got, want)
    }
}
