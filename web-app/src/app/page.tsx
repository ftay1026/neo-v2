import HeaderAuth from "@/components/header-auth";
import { Button } from "@/components/ui/button"
import { ArrowRight, CheckCircle, Brain, Clock, TrendingUp } from "lucide-react"
import Link from "next/link"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { HitPayPricingTiers } from "@/components/checkout/hitpay-pricing-constants";
import { createClient } from "@/utils/supabase/server";
import { getUser } from "@/utils/supabase/queries";
import { redirect } from "next/navigation";

export default async function Home() {
  // Check if user is authenticated and redirect to main app
  const supabase = await createClient();
  const user = await getUser(supabase);
  
  if (user) {
    redirect("/app");
  }
  return (
    <main className="min-h-dvh flex flex-col bg-background">
      <nav className="w-full max-w-7xl mx-auto h-16 flex justify-between items-center px-4 sm:px-6 lg:px-8">
        <div className="font-heading font-bold text-2xl sm:text-3xl">
          <Link href="/">NEO</Link>
        </div>
        <HeaderAuth />
      </nav>

      {/* Hero Section */}
      <section className="w-full max-w-7xl mx-auto self-center px-4 sm:px-6 lg:px-8 py-16 md:py-24">
        <div className="space-y-8 text-center max-w-4xl mx-auto">
          <h1 className="font-heading text-5xl font-bold leading-[1.1]">
            NEO: AI That Works The Way Your Brain Works
          </h1>
          
          <p className="text-xl md:text-2xl text-foreground/90 font-medium italic">
            For those who use AI to think deeper, not think less.
          </p>
          
          {/* Problem Hook - Better Typography */}
          <div className="flex flex-col items-start max-w-2xl mx-auto space-y-4 py-8">
            <p className="text-lg">So you finally found your rhythm.</p>
            <p className="text-lg">Deep in the zone. Everything clicking.</p>
            <p className="text-lg">Then your AI platform announces: <span className="font-semibold text-destructive">'Usage limit reached. Please try again at 3AM.'</span></p>
            <p className="text-lg">You're forced to either switch to an older model that keeps spouting nonsense...</p>
            <p className="text-lg">...forcing you to spend more time prompting than doing the work...</p>
            <p className="text-lg">Or go to sleep and start again tomorrow.</p>
            <p className="text-lg">But by then, all the momentum you built is gone.</p>
            <p className="text-2xl font-semibold">NEO works differently.</p>
            <p className="text-lg">A credit based system lets you work 10 hours straight or 10 minutes.</p>
            <p className="text-lg">It uses an AI that seems to 'just get it'.</p>
            <p className="text-lg">And remembers exactly what you do and how you do it.</p>
          </div>
          
          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
            <Button asChild size="lg" className="text-lg px-8 py-6">
              <Link href="/sign-in">
                Begin Your First Session
              </Link>
            </Button>
          </div>
        </div>
      </section>

      {/* Never Lose Momentum Section */}
      <section className="w-full py-16 md:py-24">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center max-w-3xl mx-auto space-y-6 mb-16">
            <h2 className="font-heading text-3xl md:text-4xl font-bold">
              Never Lose Momentum Again
            </h2>
            <p className="text-lg text-muted-foreground">
              NEO is an AI that doesn't waste your time.
            </p>
            <p className="text-xl font-semibold">
              5 features that separates NEO from the rest:
            </p>
          </div>
          
          {/* Feature Cards - Improved Design */}
          <div className="space-y-8">
            {/* Feature 1 */}
            <Card className="max-w-3xl mx-auto hover:shadow-lg transition-shadow bg-background/40">
              <CardContent className="p-8">
                <div className="flex items-start gap-6">
                  <div className="w-12 h-12 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-xl font-bold flex-shrink-0">
                    1
                  </div>
                  <div className="space-y-4">
                    <h3 className="text-2xl font-bold">Pay for momentum, not months.</h3>
                    <div className="space-y-2 text-muted-foreground">
                      <p>Credits based system means you never lose momentum.</p>
                      <p>Whether 10 minutes or 10 hours, how long you work is entirely up to you.</p>
                      <p>No watching message counters, saving important questions, or monthly subscriptions for twice-weekly use.</p>
                      <p>Your inspiration continues until you're done, not when your plan resets.</p>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Feature 2 */}
            <Card className="max-w-3xl mx-auto hover:shadow-lg transition-shadow bg-background/40">
              <CardContent className="p-8">
                <div className="flex items-start gap-6">
                  <div className="w-12 h-12 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-xl font-bold flex-shrink-0">
                    2
                  </div>
                  <div className="space-y-4">
                    <h3 className="text-2xl font-bold">AI that won't let you stay stuck.</h3>
                    <div className="space-y-2 text-muted-foreground">
                      <p>NEO's AI Coach is relentless, yet empathetic.</p>
                      <p>It analyzes your entire conversation history, spots patterns you miss, and challenges the limiting beliefs keeping you small.</p>
                      <p>While other AIs nod along or waste time with pointless questions, NEO pushes you.</p>
                      <p>Calling out that excuse, celebrating that breakthrough, and connecting dots until you see what's been there all along.</p>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Feature 3 */}
            <Card className="max-w-3xl mx-auto hover:shadow-lg transition-shadow bg-background/40">
              <CardContent className="p-8">
                <div className="flex items-start gap-6">
                  <div className="w-12 h-12 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-xl font-bold flex-shrink-0">
                    3
                  </div>
                  <div className="space-y-4">
                    <h3 className="text-2xl font-bold">Projects that actually remember what you upload.</h3>
                    <div className="space-y-2 text-muted-foreground">
                      <p>Create dedicated spaces for complex work.</p>
                      <p>Upload your research, plans, notes, and dedicated knowledgebases.</p>
                      <p>Unlike other platforms, NEO actually uses them.</p>
                      <p>Every conversation in your project reliably accesses your knowledge base.</p>
                      <p>Your strategy sessions, financial models, and market research stay connected in one workspace.</p>
                      <p>Organized work that builds on itself, with context that persists across every conversation.</p>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Feature 4 */}
            <Card className="max-w-3xl mx-auto hover:shadow-lg transition-shadow bg-background/40">
              <CardContent className="p-8">
                <div className="flex items-start gap-6">
                  <div className="w-12 h-12 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-xl font-bold flex-shrink-0">
                    4
                  </div>
                  <div className="space-y-4">
                    <h3 className="text-2xl font-bold">Compound insights with one click.</h3>
                    <div className="space-y-2 text-muted-foreground">
                      <p>Hit the Log button and NEO summarizes your entire conversation with a timestamp, adding it to your project's log.</p>
                      <p>The AI tracks when you last logged, what you discovered, how your thinking evolved.</p>
                      <p>View your log anytime.</p>
                      <p>Watch your progression from confused to clear.</p>
                      <p>NEO sees patterns across weeks of work, and reminds you of that important insight from three months ago instantly.</p>
                      <p>Your journey documented, accessible always.</p>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Feature 5 */}
            <Card className="max-w-3xl mx-auto hover:shadow-lg transition-shadow bg-background/40">
              <CardContent className="p-8">
                <div className="flex items-start gap-6">
                  <div className="w-12 h-12 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-xl font-bold flex-shrink-0">
                    5
                  </div>
                  <div className="space-y-4">
                    <h3 className="text-2xl font-bold">Deep work on documents that matter.</h3>
                    <div className="space-y-2 text-muted-foreground">
                      <p>Create and refine important documents within NEO.</p>
                      <p>Highlight any section and ask for improvements.</p>
                      <p>NEO understands the full context, suggests specific enhancements, maintains your voice.</p>
                      <p>Watch your messy first draft transform into something powerful through intelligent iteration.</p>
                      <p>Export when ready, or keep refining until it's right.</p>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* Pricing Section - Completely Redesigned */}
      <section className="w-full py-16 md:py-24">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center max-w-3xl mx-auto space-y-6 mb-16">
            <h2 className="font-heading text-3xl md:text-4xl font-bold">
              Simple Credit Pricing
            </h2>
            <p className="text-lg text-muted-foreground">
              Start free. Pay for what you use.
            </p>
          </div>
          
          <div className="flex flex-row flex-wrap gap-8 max-w-7xl mx-auto justify-center">
            {/* Free Tier */}
            <Card className="flex-1 max-w-xs min-w-[340px]">
              <CardHeader className="text-center pb-4">
                <CardTitle className="text-2xl">Free</CardTitle>
                <div className="text-4xl font-bold">$0</div>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-3">
                  <div className="flex items-center gap-3">
                    <CheckCircle className="h-5 w-5 text-primary" />
                    <span>100 credits to start</span>
                  </div>
                  <div className="flex items-center gap-3">
                    <CheckCircle className="h-5 w-5 text-primary" />
                    <span>Full access to all features</span>
                  </div>
                  <div className="flex items-center gap-3">
                    <CheckCircle className="h-5 w-5 text-primary" />
                    <span>No time limits</span>
                  </div>
                </div>
                <Button asChild className="w-full" size="lg">
                  <Link href="/sign-in">Get Started</Link>
                </Button>
              </CardContent>
            </Card>

            {/* Dynamic Pricing Tiers */}
            {HitPayPricingTiers.map((tier) => (
              <Card key={tier.id} className="flex-1 max-w-xs min-w-[340px] relative">
                {tier.featured && (
                  <div className="absolute -top-3 left-1/2 transform -translate-x-1/2">
                    <Badge className="px-3 py-1">Most Popular</Badge>
                  </div>
                )}
                <CardHeader className="text-center pb-4">
                  <div className="flex items-center justify-center gap-2 mb-2">
                    <CardTitle className="text-xl">{tier.name}</CardTitle>
                    {tier.savings && (
                      <Badge variant="secondary" className="text-xs">
                        {tier.savings}
                      </Badge>
                    )}
                  </div>
                  <div className="text-3xl font-bold">
                    ${(tier.amount / 100).toFixed(0)}
                  </div>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-3 text-sm">
                    <div className="flex items-center gap-2">
                      <CheckCircle className="h-4 w-4 text-primary" />
                      <span>{tier.credits.toLocaleString()} credits</span>
                    </div>
                    {tier.features.slice(1).map((feature, index) => (
                      <div key={index} className="flex items-center gap-2">
                        <CheckCircle className="h-4 w-4 text-primary" />
                        <span>{feature}</span>
                      </div>
                    ))}
                  </div>
                  <Button asChild className="w-full" variant="outline">
                    <Link href={`/app/checkout?tier=${tier.id}`}>
                      Buy Credits
                    </Link>
                  </Button>
                </CardContent>
              </Card>
            ))}
          </div>

          <div className="text-center mt-12 space-y-4">
            <p className="text-sm text-muted-foreground">
              Credits never expire • No monthly commitments • Pay only for what you use
            </p>
          </div>
        </div>
      </section>

      {/* Final CTA Section */}
      <section className="w-full py-16 md:py-24">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center space-y-8">
          <div className="space-y-6">
            <h2 className="font-heading text-3xl md:text-4xl font-bold">
              Start Free
            </h2>
            <p className="text-xl">
              Create your account and get 100 credits instantly. Experience AI that actually works.
            </p>
          </div>
          
          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
            <Button asChild size="lg" className="text-lg px-8 py-6">
              <Link href="/sign-in">
                Begin Your First Session
              </Link>
            </Button>
          </div>
          
          <p className="text-lg italic font-medium text-muted-foreground">
            Work when your brain works. As long as it takes.
          </p>
        </div>
      </section>
    </main>
  );
}